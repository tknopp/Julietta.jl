
import REPLCompletions

function get_completion(prefix)
  liststore = ListStore(String)
  c,r = @fetchfrom 2 REPLCompletions.completions(prefix,endof(prefix))
  for s in c
      push!(liststore, (s,) )  
  end
  return liststore
end

type Terminal <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  entry::Entry
  combo::GtkComboBoxText
  textView::TextView
end

function Terminal()

  combo = GtkComboBoxText(true)
  entry = G_.child(combo)
  textBuf = TextBuffer()
  textView = TextView(textBuf)
  
  sw = ScrolledWindow()
  push!(sw,textView)        
  
  vbox = BoxLayout(:v)
  push!(vbox,combo)
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
  #G_.inline_selection(completion,true)
  G_.completion(entry,completion)
  G_.minimum_key_length(completion,1)
  G_.text_column(completion,0)
  completed = false
  
  terminal = Terminal(vbox.handle, entry, combo, textView)
  
  execute(terminal,"import REPLCompletions")
  #execute(terminal,"using Winston")
  
  signal_connect(entry, "key-press-event") do widget, event, other...
  
    if event.keyval == Gtk.GdkKeySyms.Return
      cmd = bytestring(G_.text(terminal.entry))

      execute(terminal,cmd)
      return true
    end
    
    if event.keyval == Gtk.GdkKeySyms.Tab
		prefix = bytestring(G_.text(terminal.entry))
        
        if !completed
          @async begin
              liststore = get_completion(prefix)
            
              if length(liststore) == 0
                 completed = true
              end
              if length(liststore) == 1
                c,r = @fetchfrom 2 REPLCompletions.completions(prefix,endof(prefix))
                G_.text(terminal.entry,c[1])
                G_.position(terminal.entry,-1)
                completed = true
              end
                #	self.completing = prefix
                #G_.model(completion,liststore)
                #complete(completion)
                
                # GtkEntryCompletion apparently needs a little nudge
                # gtk.main_do_event(gtk.gdk.Event(gtk.gdk.KEY_PRESS))
                #end
		  end 
		else
		  G_.model(completion,GtkNullContainer())
		end
        return true
    end
    
    if event.keyval == Gtk.GdkKeySyms.Up
      if julietta != nothing
        cmd = prevcmd!(julietta.hist)
        G_.text(terminal.entry,cmd)
        G_.position(terminal.entry,-1)
        return true
      end
    end

    if event.keyval == Gtk.GdkKeySyms.Down
        cmd = nextcmd!(julietta.hist)
        G_.text(terminal.entry,cmd)
        G_.position(terminal.entry,-1)
        return true
    end
    
    false
  end
  
  signal_connect(entry, "changed") do widget
    completed = false
		prefix = bytestring(G_.text(terminal.entry))
        
        # TODO -> Gtk.jl
        selection_bounds(editable::Gtk.GtkEditableI)=
          bool( ccall((:gtk_editable_get_selection_bounds,Gtk.libgtk), Cint, 
	     (Ptr{Gtk.GObject},Ptr{Cint},Ptr{Cint}),editable, C_NULL,C_NULL))
         
         #println(selection_bounds(entry))

		#if event.keyval == KEY_TAB and not event.state & MOD_MASK and (
		#		prefix and not self.get_selection_bounds() and
		#		self.get_position() == len(prefix) and
		#		not self.completed):        
        
        if !completed && !selection_bounds(entry)
          @async begin
            liststore = get_completion(prefix)
        
    	    if length(liststore) == 0
		    	 completed = true
		    end

		    G_.model(completion,liststore)
		    complete(completion)
          end
		else
		  G_.model(completion,GtkNullContainer())
		end    
    return true
  end
  
  signal_connect(completion, "match-selected") do completion, model, iter
		#"""@note: This doesn't get called on inline completion."""
		#print model[iter][0], 'was selected'
		#println("Huuuhuuu ")
		completed = true
		
		#self.completing = ''
        G_.model(completion,GtkNullContainer())
        
		return    
  end
  
  signal_connect(textView, "size-allocate") do widget, event, other...
    adj = G_.vadjustment(sw)
    G_.value(adj,getproperty(adj,:upper,Float64) - getproperty(adj,:page_size,Float64) )
  end   
  
  Gtk.gc_move_ref(terminal, vbox)
end


function execute(term::Terminal, cmd::String, silent::Bool=false)
  #println("execute cmd...")
  if julietta != nothing
    if !silent
      push!(julietta.hist, cmd)
      push!(term.combo,cmd)
    end
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
    
    if s != "nothing" && !endswith(cmd,";") && !silent
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

