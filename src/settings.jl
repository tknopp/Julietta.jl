
const settings = Dict()

type SettingsDialog <: Gtk.GtkDialogI
  handle::Ptr{Gtk.GObjectI}
  cbxShowLineNumbers
  cbxHighlightCurrentLine
  btnFont
end

function SettingsDialog()

  dialog = Dialog("Settings", julietta, GtkDialogFlags.MODAL,
                        Stock.CANCEL, GtkResponseType.CANCEL,
                        Stock.OPEN, GtkResponseType.ACCEPT)

  box = G_.content_area(dialog)
  
  nb = Notebook()
  
  vboxEditor = BoxLayout(:v)
  
  
  cbxShowLineNumbers = CheckButton("Show line numbers")
  cbxHighlightCurrentLine = CheckButton("Highlight current line")
  
  push!(vboxEditor,cbxShowLineNumbers)
  push!(vboxEditor,cbxHighlightCurrentLine)
  setproperty!(cbxShowLineNumbers,:active,true)  
  setproperty!(cbxHighlightCurrentLine,:active,false)

  btnFont = FontButton()
  push!(vboxEditor,btnFont)  
  
  push!(nb, vboxEditor, "Editor")
  
  push!(box,nb)
  
  settings = SettingsDialog(dialog.handle,
    cbxShowLineNumbers,
    cbxHighlightCurrentLine,
    btnFont,
  )  

  showall(box)
  
  Gtk.gc_move_ref(settings, dialog)
end

function initSettings()
  settings[:showLineNumbers] = true
  settings[:highlightCurrentLine] = true
end

initSettings()

function acceptSettings(s::SettingsDialog)
  settings[:showLineNumbers] = getproperty(s.cbxShowLineNumbers,:active,Bool)
  settings[:highlightCurrentLine] =  getproperty(s.cbxHighlightCurrentLine,:active,Bool)
end

function applySettings(s::SettingsDialog)
  show_line_numbers(julietta.editor, settings[:showLineNumbers])
  highlight_current_line(julietta.editor, settings[:highlightCurrentLine])
  
  # font_description = G_.font_desc(widget)
  # Gtk.modifyfont(julietta.editor.currentDoc.view,font_description)
end
