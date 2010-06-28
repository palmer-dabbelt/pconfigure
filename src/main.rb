INPUT_PATH = "Configfile"
OUTPUT_PATH = "Makefile"

# Loads all the language files
require 'langbase.rb'
require 'lang/ruby.rb'
require 'lang/bash.rb'
require 'lang/g++.rb'
require 'lang/gcc.rb'
require 'lang/gas.rb'

require 'make.rb'
require 'path_fix.rb'

# How to process commands
#	if exit code is TRUE, then they kill the program
command_processors = Hash.new
command_processors["languages"] = lambda{|op, val| command_LANGUAGES(op, val)}
command_processors["targets"] = lambda{|op, val| command_TARGETS(op, val)}
command_processors["sources"] = lambda{|op, val| command_SOURCES(op, val)}
command_processors["compileopts"] = lambda{|op, val| command_COMPILEOPTS(op, val)}
command_processors["linkopts"] = lambda{|op, val| command_LINKOPTS(op, val)}
command_processors["pconfopts"] = lambda{|op, val| command_PCONFOPTS(op, val)}
command_processors["lib_targets"] = lambda{|op, val| command_LIBTARGETS(op, val)}
command_processors["hdrdir"] = lambda{|op, val| command_HDRDIR(op, val)}
command_processors["hdr_targets"] = lambda{|op, val| command_HDRTARGETS(op, val)}
command_processors["bindir"] = lambda{|op, val| command_BINDIR(op, val)}

@@srcdir = "src/"
@@libdir = "lib/"
@@bindir = "bin/"
@@hdrdir = "include/"

class IncludeEntry
	attr_accessor :file
	
	def initialize()
		@file = nil
		@path = "."
		@srcdir = "src/"
		@bindir = "bin/"
		@libdir = "lib/"
		@hdrdir = "include/"
		@o_regen = true
		@o_clean = true
		@o_doxygen = false
		@o_hdrchomp = false
	end
	
	def save()
		@srcdir = @@srcdir
		@bindir = @@bindir
		@libdir = @@libdir
		@hdrdir = @@hdrdir
		
		@o_regen = @@pconfopts_regen
		@o_clean = @@pconfpots_clean
		@o_doxygen = @@pconfopts_doxygen
		@o_hdrchomp = @@pconfopts_hdrchomp
	end
	
	def restore()
		@@srcdir = @srcdir
		@@bindir = @bindir
		@@libdir = @libdir
		@@hdrdir = @hdrdir
		
		@@pconfopts_regen = @o_regen
		@@pconfopts_clean = @o_clean
		@@pconfopts_doxygen = @o_doxygen
		@@pconfopts_hdrchomp = @o_hdrchomp
	end
end

def command_BINDIR(op, val)
	if (op != "+=")
		puts "Only support += for BINDIR"
		return true
	end
	
	@@bindir = val.strip
	
	return true
end

def command_HDRDIR(op, val)
	if (op != "=")
		puts "Only support = for HDRDIR"
		return true
	end
	
	@@hdrdir = val.strip
	return false
end

# Adds a language to the active language list (in case multiple languages conflict)
def command_LANGUAGES(op, val)
	if (@@languages[val] == nil)
		puts "Language not found"
		return true
	else
		LangBase.push(@@languages[val].new)
		return false
	end
end

# Where all our output ends up
@@makefile = Makefile.new

# Creates a new binary file for output
@@current_target = nil
class ConfigTarget
	attr_accessor :name
	attr_accessor :deps
	attr_accessor :objects
	attr_accessor :link_opts
	attr_accessor :mode
	attr_accessor :mt
	
	def initialize(name, link_opts)
		@name = name
		@deps = Array.new
		@objects = Array.new
		@link_opts = Array.new
		@mode = nil
		@mt = nil
		
		link_opts.each{|opt| @link_opts.push(opt)}
	end
end

def targets_common(op, val)
	# finishes the source tree
	command_SOURCES(nil, nil)
	@@current_source = nil
	
	# possibly compiles the last target
	if (@@current_target != nil)
		created = MakeTarget.new(@@current_target.name)
		@@current_target.mt = created
		@@current_target.deps.each{|dep|
			if (dep != created.name)
				created.deps.push(dep)
			end
		}
		tar = @@current_target.name
		dep = @@current_target.deps
		opt = @@current_target.link_opts
		obj = @@current_target.objects
		mode = @@current_target.mode
		
		LangBase.link(tar, dep, opt, obj, mode).each{|cmd|
			created.cmds.push(cmd)
		}
		
		@@makefile.all.push(tar)
		@@makefile.targets.push(created)
		
		LangBase.link_clean(tar, dep, opt, obj, mode).each{|toclean|
			@@makefile.clean.push(toclean)
		}
	end
	
	# possibly adds a new target
	if (val != nil)
		@@current_target = ConfigTarget.new(val, @@link_opts)
	end
	
	return false
end

def command_TARGETS(op, val)
	out = targets_common(op, val)
	@@current_target.mode = "b"
	@@current_target.name = "#{@@bindir}/#{@@current_target.name}".path_fix
	@@current_target.deps.push("#{@@bindir}/.pconfigure_directory")
	
	return out
end

def command_LIBTARGETS(op, val)
	out = targets_common(op, val)
	@@current_target.mode = "l"
	@@current_target.name = "#{@@libdir}/#{@@current_target.name}".path_fix
	@@current_target.deps.push("#{@@libdir}/.pconfigure_directory")
	
	return out
end

def command_HDRTARGETS(op, val)
	out = targets_common(op, val)
	@@current_target.mode = "h"
	@@current_target.name = "#{@@hdrdir}/#{@@current_target.name}".path_fix
	@@current_target.deps.push("#{@@hdrdir}/.pconfigure_directory")
	
	return out
end

# Adds a source file to the current binary file
@@current_source = nil
@@source_stack_head = nil
@@processed_sources = Array.new
class ConfigSource
	attr_accessor :name
	attr_accessor :deps
	attr_accessor :compile_opts
	attr_accessor :mt
	
	def initialize(name, compile_opts)
		@name = name
		@deps = Array.new
		@compile_opts = Array.new
		@mt = nil
		
		compile_opts.each{|opt| @compile_opts.push(opt)}
	end
end

def command_SOURCES(op, val)
	if (@@current_source != nil)
		mode = @@current_target.mode
		stack = Array.new
		processed_sources = Array.new
		
		stack.push(@@current_source)
		
		while (stack.size > 0)
			current = stack.pop
			processed_sources.push(current.name)
			
			# Fleshes out the complie deps
			LangBase.compile_deps(current.name, mode).each{|dep|
				current.deps.push(dep)
			}
			
			# Adds the last one to the compile list
			objname = LangBase.compile_object(current.name, mode)
			mt = MakeTarget.new(objname)
			current.deps.each{|dep|
				if (dep != objname)
					mt.deps.push(dep)
				end
			}
			
			current.mt = mt
			@@source_stack_head = current
			
			n = current.name
			d = current.deps
			o = current.compile_opts
			
			LangBase.compile(n, d, o, mode).each{|cmd| mt.cmds.push(cmd)}
			
			if !(@@processed_sources.include?(current.name))
				@@makefile.targets.push(mt)
			
				LangBase.compile_clean(n, d, o, mode).each{|toclean|
					@@makefile.clean.push(toclean)
				}
			end
			
			# This is what we need to pass to the linker
			LangBase.to_link(n, d, o, mode).each{|tolink|
				if !(@@current_target.objects.include?(tolink))
					@@current_target.objects.push(tolink)
				end
			}
			
			# And what it needs to relink on
			LangBase.link_deps(n, d, o, mode).each{|dep|
				if !(@@current_target.deps.include?(dep))
					@@current_target.deps.push(dep)
				end
			}
			
			# Discovers which files we also need to compile
			LangBase.compile_more(n, d, o).each{|toadd|
				if !(stack.map{|o| o.name}.include?(toadd) || processed_sources.include?(toadd))
					newsource = ConfigSource.new(toadd, @@current_source.compile_opts)
					stack.push(newsource)
				end
			}
			
			# Puts it in the global list
			@@processed_sources.push(current.name)
		end
	end
	
	if (val != nil)
		@@current_source = ConfigSource.new("#{@@srcdir}/#{val}".path_fix, @@compile_opts)
	end
	
	return false
end

# Adds a compile-time option
@@compile_opts = Array.new
def command_COMPILEOPTS(op, val)
	array = @@compile_opts
	
	if (@@current_source != nil)
		array = @@current_source.compile_opts
	end
	
	if (op == "+=")
		array.push(val)
		return false
	end
	
	if (op == "-=")
		array.delete(val)
		return false
	end
	
	return true
end

# Adds a link-time option
@@link_opts = Array.new
def command_LINKOPTS(op, val)
	array = @@link_opts
	
	if (@@current_target != nil)
		array = @@current_target.link_opts
	end
	
	if (op == "+=")
		array.push(val)
		return false
	end
	
	if (op == "-=")
		array.delete(val)
		return false
	end
	
	return true
end

# Changes the behavior of pconfigure
@@pconfopts_regen = true
@@pconfopts_clean = true
@@pconfopts_doxygen = false
@@pconfopts_hdrchomp = false
def command_PCONFOPTS(op, val)
	if (val == "regen")
		if (op == "+=")
			@@pconfopts_regen = true
			return false
		elsif (op == "-=")
			@@pconfopts_regen = false
			return false
		end
	end
	
	if (val == "clean")
		if (op == "+=")
			@@pconfopts_clean = true
			return false
		elsif (op == "-=")
			@@pconfopts_clean = false
			return false
		end
	end
	
	if (val == "doxygen")
		if (op == "+=")
			@@pconfopts_doxygen = true
			return false
		elsif (op == "-=")
			@@pconfopts_doxygen = false
			return false
		end
	end
	
	if (val == "hdrchomp")
		if (op == "+=")
			@@pconfopts_hdrchomp = true
			return false
		elsif (op == "-=")
			@@pconfopts_hdrchomp = false
			return false
		end
	end
	
	return true
end

# Begins reading from the input file
input_file = File.new(INPUT_PATH, "r")
input_linenumber = 1

while (read = input_file.gets)
	read.strip!
	
	if (read != "")
		command = read.split(" ")[0].downcase
		op = read.split(" ")[1].strip.downcase
		val = read.split(" ")[2..-1].join(" ").strip
		
		if (command_processors[command] == nil)
			puts "#{input_linenumber}: command not found #{command.inspect}"
			exit 1
		end
		
		if (command_processors[command].call(op, val))
			puts "#{input_linenumber}: error at command #{read.inspect}"
			exit 1
		end
	end
	
	input_linenumber = input_linenumber + 1
end
input_file.close

# There's a tummy targets call here to clean up
command_TARGETS(nil, nil)

# Creates the makefile
outfile = File.new(OUTPUT_PATH, "w")
@@makefile.write(outfile)
outfile.close

