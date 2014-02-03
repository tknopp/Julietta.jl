using GtkSourceWidget

import Base: open,close,push!

type SourceDocument <: Gtk.GtkScrolledWindowI
  handle::Ptr{Gtk.GObjectI}
  buffer::GtkSourceBuffer
  view::GtkSourceView
  filename::String
end

function SourceDocument(lang::GtkSourceLanguage, scheme::GtkSourceStyleScheme)
  buffer = GtkSourceBuffer(lang)
  view = GtkSourceView(buffer)
  
  style_scheme!(buffer,scheme)
  show_line_numbers!(view,true)
  auto_indent!(view,true)

  sw = ScrolledWindow()
  push!(sw,view)       
  
  sourceDocument = SourceDocument(sw.handle, buffer, view, "")
  Gtk.gc_move_ref(sourceDocument, sw)
end

function open(doc::SourceDocument)
    dlg = FileChooserDialog("Select file", NullContainer(), FileChooserAction.OPEN,
                        Stock.CANCEL, Response.CANCEL,
                        Stock.OPEN, Response.ACCEPT)
    ret = run(dlg)
    if ret == Response.ACCEPT
      doc.filename = Gtk.bytestring(Gtk._.filename(dlg),true)
      txt = open(readall, doc.filename)
      
      G_.text(doc.buffer,txt,-1)
    end
    destroy(dlg)
    
    return (ret == Response.ACCEPT)
end

function save(doc::SourceDocument)

end

function saveas(doc::SourceDocument, filename::String)

end

function close(doc::SourceDocument)

end



type SourceViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  documents::Vector{SourceDocument}
  notebook::Notebook
end

function push!(sv::SourceViewer, doc::SourceDocument)
  push!(sv.notebook, doc, basename(doc.filename))
  push!(sv.documents, doc)
  showall(sv.notebook)   
end

function SourceViewer()
  
  m = GtkSourceLanguageManager()
  l = GtkSourceWidget.language(m,"julia")
  
  documents = SourceDocument[]
  currentDoc = nothing
  
  sm = GtkSourceStyleSchemeManager()
  s = style_scheme(sm,"kate")
  
  nb = Notebook()
  
  btnOpen = ToolButton("gtk-open")
  btnSave = ToolButton("gtk-save")
  btnSaveAs = ToolButton("gtk-save-as")  
  btnUndo = ToolButton("gtk-undo")
  btnRedo = ToolButton("gtk-redo")

  toolbar = Toolbar()
  push!(toolbar,btnOpen,btnSave,btnSaveAs,SeparatorToolItem())
  push!(toolbar,btnUndo,btnRedo)
  #G_.style(toolbar,ToolbarStyle.BOTH)  
  
  
  vbox = BoxLayout(:v)
  push!(vbox,toolbar)
  push!(vbox,nb)
  setproperty!(vbox,:expand,nb,true)
  
  win = GtkWindow("Source Viewer",600,400)
  push!(win,vbox)
  showall(win)  
  
  sourceViewer = SourceViewer(win.handle, documents, nb) 
  
  push!(sourceViewer, SourceDocument(l,s))
  currentDoc = sourceViewer.documents[1]
  
  signal_connect(btnOpen, "clicked") do widget
    doc = SourceDocument(l,s)
    if open(doc)
      push!(sourceViewer, doc)
    end
  end
  
  signal_connect(btnUndo, "clicked") do widget
    undo!(currentDoc.buffer) #TODO use active buffer
    G_.sensitive(btnUndo, canundo(currentDoc.buffer))
    G_.sensitive(btnRedo, canredo(currentDoc.buffer))
  end
  
  signal_connect(btnRedo, "clicked") do widget
    redo!(currentDoc.buffer) #TODO use active buffer
    G_.sensitive(btnUndo, canundo(currentDoc.buffer))
    G_.sensitive(btnRedo, canredo(currentDoc.buffer))    
  end  

  signal_connect(currentDoc.buffer, "changed") do widget, args...
    G_.sensitive(btnUndo, canundo(currentDoc.buffer))
    G_.sensitive(btnRedo, canredo(currentDoc.buffer))
  end  
  

  Gtk.gc_move_ref(sourceViewer, win)
end
