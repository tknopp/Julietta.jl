using GtkSourceWidget

type Editor <: Gtk.GtkBox
  handle::Ptr{Gtk.GObject}
  documents::Vector{SourceDocument}
  notebook::Notebook
  lang
  style
  currentDoc
  currentPage::Int32
end

function Editor()
  
  m = @GtkSourceLanguageManager()
  l = GtkSourceWidget.language(m,"julia")
  
  documents = SourceDocument[]
  
  sm = @GtkSourceStyleSchemeManager()
  s = style_scheme(sm,"kate")
  
  nb = @Notebook()
  
  vbox = @Box(:v)
  push!(vbox,nb)
  setproperty!(vbox,:expand,nb,true)
  
  editor = Editor(vbox.handle, documents, nb, l, s, nothing, 0 ) 
  
  push!(editor, SourceDocument(l,s))
  
  signal_connect(nb, "switch-page") do widget, page, page_num, args...
    julietta.editor.currentPage = page_num
    julietta.editor.currentDoc = page
  end  
  
  @schedule begin
     while(true)
       if editor.currentDoc != nothing
         parse(editor.currentDoc)
       end
       sleep(1)
     end
   end   
  
  Gtk.gc_move_ref(editor, vbox)
  editor
end

function open(editor::Editor, filename::String)
  for d in editor.documents
    if d.filename == filename
        editor.currentPage = pagenumber(editor.notebook, d)
        editor.currentDoc = d
        showall(d)
        G_.current_page(editor.notebook, editor.currentPage)
      return
    end
  end
  doc = SourceDocument(editor.lang, editor.style)
  open(doc, filename)
  push!(editor,doc)
end


function push!(editor::Editor, doc::SourceDocument)

  hbox = @Box(:h)
  push!(hbox,doc.label)
  push!(hbox,doc.btnClose) 

  push!(editor.notebook, doc, hbox)
  push!(editor.documents, doc)
  editor.currentPage = pagenumber(editor.notebook, doc)
  editor.currentDoc = doc
  
  showall(doc)
  G_.current_page(editor.notebook, editor.currentPage)
  G_.tab_reorderable(editor.notebook,doc,true)
  
  signal_connect(doc.btnClose, "clicked") do widget
    i = pagenumber(editor.notebook, doc) + 1 # we need to fix this in Gtk.jl
    
    if close(doc)
      #abort
      return
    end
    
    splice!(editor.notebook,i)
    # TODO refactor!!!
    j = -1
    for (l,d) in enumerate(editor.documents)
      if is(d,doc)
        j = l
        break
      end
    end
    splice!(editor.documents, j)
  end  
  
  showall(editor.notebook)   
end

### settings

function show_line_numbers(editor::Editor, val::Bool)
  for d in editor.documents
    show_line_numbers!(d.view, val )
  end
end

function highlight_current_line(editor::Editor, val::Bool)
  for d in editor.documents
    highlight_current_line!(d.view, val )
  end
end
