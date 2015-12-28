NpmLicenseCheckerView = require './npm-license-checker-view'
request = require 'superagent'
async = require 'async'

{CompositeDisposable} = require 'atom'

module.exports = NpmLicenseChecker =
  npmLicenseCheckerView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    #@npmLicenseCheckerView = new NpmLicenseCheckerView(state.npmLicenseCheckerViewState)
    #@modalPanel = atom.workspace.addModalPanel(item: @npmLicenseCheckerView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'npm-license-checker:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @npmLicenseCheckerView.destroy()

  serialize: ->
    npmLicenseCheckerViewState: @npmLicenseCheckerView.serialize()

  toggle: ->
    console.log 'NpmLicenseChecker was toggled!'
    editor = atom.workspace.getActiveTextEditor()

    if editor.getTitle() != 'package.json'
      console.log 'NOT A PACKAGE.JSON!'
    else
      console.log 'Analyzing ' + editor.getTitle()
      packageFile = JSON.parse(editor.getText())
      dependencies = packageFile.dependencies
      devDependencies = packageFile.devDependencies

      async.waterfall([
        (callback) ->
          (atom.workspace.open('',{
            "newWindow" : false
            }))
            .then((newTextEditor) ->
              newTextEditor.insertText('Package Name; Installed Version; License')
              newTextEditor.insertNewline()
              callback(null, newTextEditor))
        ,
        #getting and printing dependencies
        ((newTextEditor, callback) ->
          for packageName, version of dependencies
            installedVersion = @getSimpleSanitizedVersion(version)
            @getPackageInfo(newTextEditor, packageName, installedVersion)
          callback(null, newTextEditor)
        ).bind(this)
        ,
        #getting and printing DEVdependencies
        ((newTextEditor, callback) ->
          for packageName, version of devDependencies
            installedVersion = @getSimpleSanitizedVersion(version)
            @getPackageInfo(newTextEditor, packageName, installedVersion)
          callback(null, newTextEditor)
        ).bind(this)
        ], (err, results) ->
          if (err)
            throw err
        )

  getPackageInfo: (textEditor, packageName, installedVersion) ->
    request.get('http://registry.npmjs.org/' + packageName).end((err, res) ->
      throw err if err?
      packageInfo = res.body
      license = JSON.stringify(packageInfo.versions[installedVersion].license) || '"UNDEFINED or UNLICENSED, check http://npmjs.org/' + packageName + '"'
      textEditor.insertText(packageName + '; ' + installedVersion + '; ' + license)
      textEditor.insertNewline()
    )

  #very simple first version sanitization
  getSimpleSanitizedVersion: (version) ->
    cleanVersion = version.replace('^', '')
    cleanVersion = cleanVersion.replace('~', '')
    cleanVersion = cleanVersion.replace('<=', '')
    cleanVersion = cleanVersion.replace('<', '')
    cleanVersion = cleanVersion.replace('>=', '')
    cleanVersion = cleanVersion.replace('>', '')
    cleanVersion = cleanVersion.replace('=', '')
    cleanVersion = cleanVersion.replace('x', '0')
    cleanVersion = cleanVersion.replace('X', '0')
    cleanVersion = cleanVersion.replace('*', '0')
    return cleanVersion
