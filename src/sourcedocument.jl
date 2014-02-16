using GtkSourceWidget


type SourceDocument <: Gtk.GtkScrolledWindowI
  handle::Ptr{Gtk.GObjectI}
  buffer::GtkSourceBuffer
  view::GtkSourceView
  filename::String
  unsavedChanges::Bool
  label
  btnClose
end

function SourceDocument(lang::GtkSourceLanguage, scheme::GtkSourceStyleScheme)
  buffer = GtkSourceBuffer(lang)
  view = GtkSourceView(buffer)
  
  style_scheme!(buffer,scheme)
  show_line_numbers!(view,settings[:showLineNumbers])
  auto_indent!(view,true)
  highlight_matching_brackets(buffer,true)
  highlight_current_line!(view, settings[:highlightCurrentLine])
  
  sw = ScrolledWindow()
  push!(sw,view)       
  
  label = Label("New File")
  G_.margin_right(label,4)

  imClose = Image(stock_id="gtk-close",size=:MENU)

  btnClose = Button()
  G_.relief(btnClose, GtkReliefStyle.NONE)
  G_.focus_on_click(btnClose, false)
  
  btnstyle =  ".button {\n" *
          "-GtkButton-default-border : 0px;\n" *
          "-GtkButton-default-outside-border : 0px;\n" *
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
  
  tag = Gtk.create_tag(buffer, "error", underline=4)  
  
  signal_connect(buffer, "changed") do widget, args...
    #TODO: only first time
    s = julietta.editor.currentDoc.filename
    s = isempty(s) ? "New File" : basename(s)
    G_.text(label,"*"*s)
    julietta.editor.currentDoc.unsavedChanges = true
  end 
  
  sourceDocument = SourceDocument(sw.handle, buffer, view, "", false, label, btnClose)
  Gtk.gc_move_ref(sourceDocument, sw)
end

function parse(doc::SourceDocument)
  Gtk.remove_tag(doc.buffer,"error",G_.start_iter(doc.buffer), G_.end_iter(doc.buffer))  
  
  cmd = text(doc)
  
  pos = 1
  endpos = length(cmd)
  valid = true
  while true
    ast,pos = parse(cmd, pos, greedy=true, raise=false)
    
    if ast != nothing && typeof(ast) != Symbol &&
      (ast.head == :error || ast.head == :incomplete || ast.head == :continue)
      valid = false
      #println("pos = ", pos)
      it = Gtk.GtkTextIter(doc.buffer,pos) 
  
      lineNr = getproperty(it, :line, Cint)
      #println("lineNr = ", lineNr)
      lineLen = getproperty(it, "chars_in_line", Cint)
      #println("lineLen = ", lineLen)
  
      if lineLen > 0 
        lineLen -= 1
      end
  
      itStart = Gtk.GtkTextIter(doc.buffer, lineNr+1, 1)     
      itEnd = Gtk.GtkTextIter(doc.buffer, lineNr+1, lineLen+1) 
       
      Gtk.apply_tag(doc.buffer, "error", itStart, itEnd)

    end
    
    if pos >= endpos
      break
    end   
    
  end
  
  if !valid
    G_.markup(doc.label, 
       "<span foreground=\"red\">" * bytestring(G_.text(doc.label)) * "</span>")
  else
    G_.markup(doc.label, 
       "<span foreground=\"green\">" * bytestring(G_.text(doc.label)) * "</span>")
  end
end

function open(doc::SourceDocument, filename::String)
  doc.filename = filename
  txt = open(readall, doc.filename)
      
  G_.text(doc.buffer,txt,-1)
  G_.text(doc.label,basename(doc.filename))
  
  parse(doc)
end

function open(doc::SourceDocument)
    dlg = FileChooserDialog("Select file", NullContainer(), FileChooserAction.OPEN,
                        "gtk-cancel", GtkResponseType.CANCEL,
                        "gtk-open", GtkResponseType.ACCEPT)
    ret = run(dlg)
    if ret == GtkResponseType.ACCEPT
      open(doc, Gtk.bytestring(Gtk._.filename(dlg),true) )
    end
    destroy(dlg)
    
    return (ret == GtkResponseType.ACCEPT)
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
  G_.text(doc.label,basename(doc.filename))
  doc.unsavedChanges = false
end

function saveas(doc::SourceDocument)
  dlg = FileChooserDialog("Select file", NullContainer(), FileChooserAction.SAVE,
                               "gtk-cancel", GtkResponseType.CANCEL,
                               "gtk-save", GtkResponseType.ACCEPT)
  G_.do_overwrite_confirmation(dlg,true)
    
  if isempty(doc.filename)
    G_.current_name(dlg,"Untitled document")
  else
    G_.filename(dlg,doc.filename)
  end
  
  ret = run(dlg)
  if ret == GtkResponseType.ACCEPT
    doc.filename = Gtk.bytestring(Gtk._.filename(dlg),true)
    save(doc)
  end
  destroy(dlg)
  
end

function close(doc::SourceDocument)
  abort = false
  if doc.unsavedChanges
  
    dlg = MessageDialog(julietta, GtkDialogFlags.MODAL, GtkMessageType.QUESTION,
                      "File has unsaved changes. Do you want to save it?",
                        "gtk-cancel", GtkResponseType.CANCEL,
                        "gtk-no", GtkResponseType.NO,
                        "gtk-yes", GtkResponseType.YES)
  
    ret = run(dlg)

    if ret == GtkResponseType.YES
      save(doc)
    end
    if ret == GtkResponseType.CANCEL
      abort = true
    end    
    destroy(dlg)

  end
  abort
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
  
  user_action(doc.buffer) do buffer
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if !getproperty(it, :ends_line, Bool)
      insert!(doc.buffer,it,"\t")
    end
  end
  
  end 
end

function unindent!(doc::SourceDocument)
  b, itStart, itEnd = G_.selection_bounds(doc.buffer)
  start_line = getproperty(itStart, :line, Cint)
  end_line = getproperty(itEnd, :line, Cint)
 
  # if the end of the selection is before the first character on a line,
  # don't indent it
  if (getproperty(itEnd,:visible_line_offset,Cint) == 0) && (end_line > start_line)
    end_line -= 1
  end
  
  user_action(doc.buffer) do buffer
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if getproperty(it, :char, Char) == '\t'
      it2 = it + 1
      #skip(Gtk.mutable(it2),1)
      #range_ = Gtk.GtkTextRange(it,it2)
      splice!(doc.buffer,it2)#range_)
     end
  end
  
  end 
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
  
  user_action(doc.buffer) do buffer
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if !getproperty(it, :ends_line, Bool)
      insert!(doc.buffer,it,"#")
    end
  end
  
  end 
end

function uncomment!(doc::SourceDocument)
  b, itStart, itEnd = G_.selection_bounds(doc.buffer)
  start_line = getproperty(itStart, :line, Cint)
  end_line = getproperty(itEnd, :line, Cint)
 
  # if the end of the selection is before the first character on a line,
  # don't indent it
  if (getproperty(itEnd,:visible_line_offset,Cint) == 0) && (end_line > start_line)
    end_line -= 1
  end
  
  user_action(doc.buffer) do buffer
  
  for i=start_line:end_line
    it = Gtk.GtkTextIter(doc.buffer, i+1, 1)
    if getproperty(it, :char, Char) == '#'
      it2 = it + 1
      splice!(doc.buffer,it2)
     end
  end
 
  end    
end