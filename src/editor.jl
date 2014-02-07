using GtkSourceWidget

type Editor <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  documents::Vector{SourceDocument}
  notebook::Notebook
  lang
  style
  currentDoc
  currentPage::Int32
end

function Editor()
  
  m = GtkSourceLanguageManager()
  l = GtkSourceWidget.language(m,"julia")
  
  documents = SourceDocument[]
  
  sm = GtkSourceStyleSchemeManager()
  s = style_scheme(sm,"kate")
  
  nb = Notebook()
  
  vbox = BoxLayout(:v)
  push!(vbox,nb)
 setproperty!(vbox,:expand,nb,true)
  
  editor = Editor(vbox.handle, documents, nb, l, s, nothing, 0 ) 
  
  push!(editor, SourceDocument(l,s))
  
  signal_connect(nb, "switch-page") do widget, page, page_num, args...
    julietta.editor.currentPage = page_num
    julietta.editor.currentDoc = page
  end  
  
  Gtk.gc_move_ref(editor, vbox)
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

  push!(editor.notebook, doc, hbox)
  push!(editor.documents, doc)
  editor.currentPage = pagenumber(editor.notebook, doc)
  editor.currentDoc = doc
  
  showall(doc)
  G_.current_page(editor.notebook, editor.currentPage)
  G_.tab_reorderable(editor.notebook,doc,true)
  
  signal_connect(btnClose, "clicked") do widget
    i = pagenumber(editor.notebook, doc)
    splice!(editor.notebook,i)
  end  
  
  showall(editor.notebook)   
end