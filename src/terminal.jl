
import REPLCompletions

function get_completion(prefix)
  liststore = ListStore(String)
  c,r = REPLCompletions.completions(prefix,endof(prefix))
  for s in c
      push!(liststore, (s,) )  
  end
  return liststore
end

type Terminal <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  entry::Entry
  textView::TextView
end

function Terminal()
  
  entry = Entry()
  textBuf = TextBuffer()
  textView = TextView(textBuf)
  
  sw = ScrolledWindow()
  push!(sw,textView)        
  
  vbox = BoxLayout(:v)
  push!(vbox,entry)
  push!(vbox,sw)
  setproperty!(vbox,:expand,sw,true)
    
  rd, wr = redirect_stdout()

  @schedule begin
     while(true)
        response = readavailable(rd)
        if !isempty(response)
          response = replace(response, "From worker 2:	", "")
          insert!(textView,string(response)) #,"\n"
        end
     end
   end
  
  # Redirect stderr on worker  
  @spawnat 2 begin
    rderr, wrerr = redirect_stderr()
    @schedule begin
      while(true)
         response = readavailable(rderr)
         print(response)
      end
    end
  end
  
  completion = EntryCompletion()
  G_.model(completion,GtkNullContainer())
  G_.inline_selection(completion,true)
  G_.completion(entry,completion)
  G_.minimum_key_length(completion,1)
  G_.text_column(completion,0)
  completed = false
  
  terminal = Terminal(vbox.handle, entry, textView)
  
  signal_connect(entry, "key-press-event") do widget, event, other...
  
    if event.keyval == Gtk.GdkKeySyms.Return
      cmd = bytestring(G_.text(terminal.entry))

      execute(terminal,cmd)
    end
    
    if event.keyval == Gtk.GdkKeySyms.Tab
		prefix = bytestring(G_.text(terminal.entry))
        
        if !completed
          liststore = get_completion(prefix)
        
    	  if length(liststore) == 0
			 completed = true
		  end
		  if length(liststore) == 1
		    c,r = REPLCompletions.completions(prefix,endof(prefix))
		    G_.text(terminal.entry,c[1])
		    G_.position(terminal.entry,-1)
			completed = true
		  else
			#	self.completing = prefix
		    G_.model(completion,liststore)
		    complete(completion)
		    
			# GtkEntryCompletion apparently needs a little nudge
			# gtk.main_do_event(gtk.gdk.Event(gtk.gdk.KEY_PRESS))
		  end
		  return true
		else
		  G_.model(completion,GtkNullContainer())
		  return true #false
		end
    end    
    0
  end
  
  signal_connect(entry, "changed") do widget
    completed = false
		prefix = bytestring(G_.text(terminal.entry))
        
        if !completed
          liststore = get_completion(prefix)
        
    	  if length(liststore) == 0
			 completed = true
		  end
		  #if length(liststore) == 1
		  #  c,r = REPLCompletions.completions(prefix,endof(prefix))
		  #  G_.text(terminal.entry,c[1])
		  #  G_.position(terminal.entry,-1)
		#	completed = true
		 # else
			#	self.completing = prefix
		    G_.model(completion,liststore)
		    complete(completion)
		    
			# GtkEntryCompletion apparently needs a little nudge
			# gtk.main_do_event(gtk.gdk.Event(gtk.gdk.KEY_PRESS))
		  #end
		  return true
		else
		  G_.model(completion,GtkNullContainer())
		  return true #false
		end    
    
  end
    
  signal_connect(textView, "size-allocate") do widget, event, other...
    adj = G_.vadjustment(sw)
    G_.value(adj,getproperty(adj,:upper,Float64) - getproperty(adj,:page_size,Float64) )
  end   
  
  Gtk.gc_move_ref(terminal, vbox)
end


function execute(term::Terminal, cmd::String)
  #println("execute cmd...")
  if julietta != nothing
    push!(julietta.hist, cmd)
    start(julietta.spinner)
  end
  G_.sensitive(term.entry, false)

  outputTxt = string("julia> ", cmd, "\n" )
  #insert!(textBuf,G_.end_iter(textBuf),outputTxt)
  insert!(term.textView,outputTxt)

  #if !endswith(cmd,";")
  #  cmd = string(cmd,";show(ans)")
  #end  
      
  ex = Base.parse_input_line(cmd)
  #eval(ex)
  @async begin
    #remotecall_wait(2, eval, ex)
    s = @fetchfrom 2 begin
      ex = expand(ex)
      value = eval(Main,ex)
      eval(Main, :(ans = $(Expr(:quote, value))))
      repr(value)
    end
    
    if s != "nothing" && !endswith(cmd,";")
      println(s)
    end
    
    if julietta != nothing
      #println("execute cmd...2")
      update!(julietta.work)

      stop(julietta.spinner)
      G_.sensitive(julietta.term.entry, true)
      G_.text(julietta.term.entry,"")      
    end
  end
end

