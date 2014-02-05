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

function text(doc::SourceDocument)
  itStart = Gtk.GtkTextIter(doc.buffer)
  itEnd = Gtk.GtkTextIter(doc.buffer)
  ccall((:gtk_text_buffer_get_end_iter,Gtk.libgtk),Void,
        (Ptr{Gtk.GObject},Ptr{Void}),doc.buffer,itEnd.handle)
  txt = bytestring( G_.text(doc.buffer, itStart.handle, itEnd.handle, false) )
end

function save(doc::SourceDocument)
  stream = open(doc.filename, "w")
  write(stream,text(doc))
  close(stream)
end

function saveas(doc::SourceDocument)
  dlg = FileChooserDialog("Select file", NullContainer(), FileChooserAction.SAVE,
                               Stock.CANCEL, Response.CANCEL,
                               Stock.SAVE, Response.ACCEPT)
  G_.do_overwrite_confirmation(dlg,true)
    
  if isempty(doc.filename)
    G_.current_name(dlg,"Untitled document")
  else
    G_.filename(dlg,doc.filename)
  end
  
  ret = run(dlg)
  if ret == Response.ACCEPT
    doc.filename = Gtk.bytestring(Gtk._.filename(dlg),true)
    save(doc)
  end
  destroy(dlg)
  
end

function close(doc::SourceDocument)

end



type SourceViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  documents::Vector{SourceDocument}
  notebook::Notebook
end

function push!(sv::SourceViewer, doc::SourceDocument)
  push!(sv.notebook, doc, isempty(doc.filename) ? "New File" : basename(doc.filename))
  push!(sv.documents, doc)
  i = pagenumber(sv.notebook, doc)
  
  showall(doc)
  G_.current_page(sv.notebook, i)
  G_.tab_reorderable(sv.notebook,doc,true)
  
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
  
  btnNew = ToolButton("gtk-new")
  btnOpen = ToolButton("gtk-open")
  btnSave = ToolButton("gtk-save")
  btnSaveAs = ToolButton("gtk-save-as")  
  btnUndo = ToolButton("gtk-undo")
  btnRedo = ToolButton("gtk-redo")
  btnRun = ToolButton("gtk-media-play")
  btnIndent = ToolButton("gtk-indent")
  btnUnindent = ToolButton("gtk-unindent")  

  toolItemCbx = ToolItem()
  cbxShowLineNumbers = CheckButton("Show line numbers")
  cbxHighlightCurrentLine = CheckButton("Highlight current line")
  
  vboxCbx = BoxLayout(:v)
  push!(vboxCbx,cbxShowLineNumbers)
  push!(vboxCbx,cbxHighlightCurrentLine)
  setproperty!(cbxShowLineNumbers,:active,true)  
  setproperty!(cbxHighlightCurrentLine,:active,false)
  
  push!(toolItemCbx,vboxCbx)
  
  toolbar = Toolbar()
  push!(toolbar,btnNew,btnOpen,btnSave,btnSaveAs,SeparatorToolItem())
  push!(toolbar,btnUndo,btnRedo,SeparatorToolItem())
  push!(toolbar,btnRun,SeparatorToolItem())
  push!(toolbar,btnIndent,btnUnindent,SeparatorToolItem()) 
  push!(toolbar,toolItemCbx)
  #G_.style(toolbar,ToolbarStyle.BOTH)  
  
  
  vbox = BoxLayout(:v)
  push!(vbox,toolbar)
  push!(vbox,nb)
  setproperty!(vbox,:expand,nb,true)
  
  win = GtkWindow("Source Viewer",800,768)
  push!(win,vbox)
  showall(win)  
  
  sourceViewer = SourceViewer(win.handle, documents, nb) 
  
  push!(sourceViewer, SourceDocument(l,s))
  currentDoc = sourceViewer.documents[1]
  currentPage = 1
  
  signal_connect(btnNew, "clicked") do widget
    push!(sourceViewer, SourceDocument(l,s))
  end  
  
  signal_connect(btnOpen, "clicked") do widget
    doc = SourceDocument(l,s)
    if open(doc)
      push!(sourceViewer, doc)
    end
  end
  
  signal_connect(btnSave, "clicked") do widget
    save(currentDoc)
  end  
  
  signal_connect(btnSaveAs, "clicked") do widget
    saveas(currentDoc)
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
  
  signal_connect(btnIndent, "clicked") do widget
    indent!(currentDoc)
  end
  
  signal_connect(btnUnindent, "clicked") do widget
    #TODO
  end    

  signal_connect(currentDoc.buffer, "changed") do widget, args...
    G_.sensitive(btnUndo, canundo(currentDoc.buffer))
    G_.sensitive(btnRedo, canredo(currentDoc.buffer))
  end  
  
  signal_connect(nb, "switch-page") do widget, page, page_num, args...
    currentPage = page_num
    currentDoc = page
  end
  
  
  signal_connect(btnRun, "clicked") do widget
    script = text(currentDoc)
    if julietta != nothing
      execute(julietta.term, script)
    end
  end
  
  signal_connect(cbxShowLineNumbers, "toggled") do widget
    #TODO: Do it in all views
    show_line_numbers!(currentDoc.view, getproperty(cbxShowLineNumbers,:active,Bool) )
  end
  
  signal_connect(cbxHighlightCurrentLine, "toggled") do widget
    #TODO: Do it in all views
    highlight_current_line!(currentDoc.view, getproperty(cbxHighlightCurrentLine,:active,Bool) )
  end
  
  Gtk.gc_move_ref(sourceViewer, win)
end
