# Copied from https://github.com/can-lehmann/owlkettle/blob/main/examples/dialogs/custom_dialog.nim
import owlkettle
import std/envvars
import defs


viewable Property:
  name: string
  child: Widget

method view(property: PropertyState): Widget =
  result = gui:
    Box:
      orient = OrientX
      spacing = 6
      
      Label:
        text = property.name
        xAlign = 0
      
      insert(property.child) {.expand: false.}

proc add(property: Property, child: Widget) =
  property.hasChild = true
  property.valChild = child


viewable UserDialog:
  user: User

method view(dialog: UserDialogState): Widget =
  dialog.user.name = getEnv "USER"
  result = gui:
    Dialog:
      title = "Priviledge Escalation"
      defaultSize = (320, 0)
      
      DialogButton {.addButton.}:
        text = "Continue"
        style = [ButtonSuggested]
        res = DialogAccept
      
      DialogButton {.addButton.}:
        text = "Cancel"
        res = DialogCancel
      
      Box:
        orient = OrientY
        spacing = 6
        margin = 12
        
        Property:
          name = "Username"
          Entry:
            text = dialog.user.name
            proc changed(name: string) =
              dialog.user.name = name
        
        Property:
          name = "Password"
          Entry:
            text = dialog.user.password
            visibility = false
            proc changed(password: string) =
              dialog.user.password = password

proc askpass*(app: AppState): User =
  if app.user.name != "": return app.user
  let (res, state) = app.open(gui(UserDialog()))
  if res.kind == DialogAccept:
    result.name = UserDialogState(state).user.name
    result.password = UserDialogState(state).user.password
