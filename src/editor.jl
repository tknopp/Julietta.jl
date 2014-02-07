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

function open(doc::SourceDocument, filename::String)
  doc.filename = filename
  txt = open(readall, doc.filename)
      
  G_.text(doc.buffer,txt,-1)
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
  itStart = G_.start_iter(doc.buffer)
  itEnd = G_.end_iter(doc.buffer)
  txt = bytestring( G_.text(doc.buffer, Gtk.mutable(itStart), Gtk.mutable(itEnd), false) )
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

function indent!(doc::SourceDocument)
  b, itStart, itEnd = G_.selection_bounds(doc.buffer)
  start_line = getproperty(itStart, :line, Cint)
  end_line = getproperty(itEnd, :line, Cint)
 
  # if the end of the selection is before the first character on a line,
  # don't indent it
  if (getproperty(itEnd,:visible_line_offset,Cint) == 0) && (end_line > start_line)
    end_line -= 1
  end
  
  Gtk.begin_user_action(doc.buffer)
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if !getproperty(it, :ends_line, Bool)
      insert!(doc.buffer,it,"\t")
    end
  end
  
  Gtk.end_user_action(doc.buffer)  
end

function unindent!(doc::SourceDocument)
  ### THIS FUNCTION DOES NOT WORK. Why?
  b, itStart, itEnd = G_.selection_bounds(doc.buffer)
  start_line = getproperty(itStart, :line, Cint)
  end_line = getproperty(itEnd, :line, Cint)
 
  # if the end of the selection is before the first character on a line,
  # don't indent it
  if (getproperty(itEnd,:visible_line_offset,Cint) == 0) && (end_line > start_line)
    end_line -= 1
  end
  
  Gtk.begin_user_action(doc.buffer)
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if getproperty(it, :char, Char) == '\t'
      it2 = copy(it)
      skip(Gtk.mutable(it2),1)
      range_ = Gtk.GtkTextRange(it,it2)
      splice!(doc.buffer,range_)
     end
  end
  
  Gtk.end_user_action(doc.buffer)  
end

function comment!(doc::SourceDocument)
  b, itStart, itEnd = G_.selection_bounds(doc.buffer)
  start_line = getproperty(itStart, :line, Cint)
  end_line = getproperty(itEnd, :line, Cint)
 
  # if the end of the selection is before the first character on a line,
  # don't indent it
  if (getproperty(itEnd,:visible_line_offset,Cint) == 0) && (end_line > start_line)
    end_line -= 1
  end
  
  Gtk.begin_user_action(doc.buffer)
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if !getproperty(it, :ends_line, Bool)
      insert!(doc.buffer,it,"#")
    end
  end
  
  Gtk.end_user_action(doc.buffer)  
end

type SourceViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  documents::Vector{SourceDocument}
  notebook::Notebook
  lang
  style
end

function push!(sv::SourceViewer, doc::SourceDocument)

  label = Label(isempty(doc.filename) ? "New File" : basename(doc.filename))
  G_.margin_right(label,4)
  hbox = BoxLayout(:h)
  push!(hbox,label)
  imClose = Image(stock_id="gtk-close",size=:menu)

  btnClose = Button()
  G_.relief(btnClose, ReliefStyle.NONE)
  G_.focus_on_click(btnClose, false)
  
  btnstyle =  ".button {\n" *
          "-GtkButton-default-border : 0px;\n" *
          "-GtkButton-default-outside-border : 2px;\n" *
          "-GtkButton-inner-border: 0px;\n" *
          "-GtkWidget-focus-line-width : 0px;\n" *
          "-GtkWidget-focus-padding : 0px;\n" *
          "padding: 0px;\n" *
          "}"
  provider = CssProvider(data=btnstyle)
  
  # TODO fix
  sc = StyleContext(convert(Ptr{Gtk.GObject},G_.style_context(btnClose)))
  # 600 = GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
  push!(sc, provider, 600)
  
  push!(btnClose,imClose)
  push!(hbox,btnClose) 

  push!(sv.notebook, doc, hbox)
  push!(sv.documents, doc)
  i = pagenumber(sv.notebook, doc)
  
  showall(doc)
  G_.current_page(sv.notebook, i)
  G_.tab_reorderable(sv.notebook,doc,true)
  
  signal_connect(btnClose, "clicked") do widget
    i = pagenumber(sv.notebook, doc)
    splice!(sv.notebook,i)
  end  
  
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
  btnComment = ToolButton("gtk-indent")  

  toolItemCbx = ToolItem()
  cbxShowLineNumbers = CheckButton("Show line numbers")
  cbxHighlightCurrentLine = CheckButton("Highlight current line")
  
  vboxCbx = BoxLayout(:v)
  push!(vboxCbx,cbxShowLineNumbers)
  push!(vboxCbx,cbxHighlightCurrentLine)
  setproperty!(cbxShowLineNumbers,:active,true)  
  setproperty!(cbxHighlightCurrentLine,:active,false)
  
  push!(toolItemCbx,vboxCbx)
  
  btnFont = FontButton()
  toolItemFont = ToolItem()
  push!(toolItemFont,btnFont)
  
  toolbar = Toolbar()
  push!(toolbar,btnNew,btnOpen,btnSave,btnSaveAs,SeparatorToolItem())
  push!(toolbar,btnUndo,btnRedo,SeparatorToolItem())
  push!(toolbar,btnRun,SeparatorToolItem())
  push!(toolbar,btnIndent,btnUnindent,SeparatorToolItem()) 
  push!(toolbar,btnComment,SeparatorToolItem()) 
  push!(toolbar,toolItemCbx,toolItemFont)
  
  #G_.style(toolbar,ToolbarStyle.BOTH)  
  
  
  vbox = BoxLayout(:v)
  push!(vbox,toolbar)
  push!(vbox,nb)
  setproperty!(vbox,:expand,nb,true)
  
  win = GtkWindow("Source Viewer",800,768)
  push!(win,vbox)
  showall(win)  
  
  sourceViewer = SourceViewer(win.handle, documents, nb, l, s) 
  
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
    unindent!(currentDoc)
  end
  
  signal_connect(btnComment, "clicked") do widget
    comment!(currentDoc)
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
  
  signal_connect(btnFont, "font-set") do widget
    font_description = G_.font_desc(widget)
    Gtk.modifyfont(currentDoc.view,font_description)
  end    
  
  Gtk.gc_move_ref(sourceViewer, win)
end

function open(viewer::SourceViewer, filename::String)
  for d in viewer.documents
    if d.filename == filename
        i = pagenumber(viewer.notebook, d)
        showall(d)
        G_.current_page(viewer.notebook, i)
      return
    end
  end
  doc = SourceDocument(viewer.lang, viewer.style)
  open(doc, filename)
  push!(viewer,doc)
end
