using GtkSourceWidget


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