class String
	def starts_with(other)
		if (self.size < other.size)
			return false
		else
			return self[0 .. (other.size - 1)] == other[0 .. (other.size - 1)]
		end
	end
	
	def ends_with(other)
		return self.reverse.starts_with(other.reverse)
	end
	
	def chomp_front!(other)
		replace(chomp_front(other))
	end
	
	def chomp_front(other)
		return self.reverse.chomp(other.reverse).reverse
	end
	
	def path_clean!()
		out = Array.new
		
		self.split("/").each{|item|
			if (item == "..")
				out.pop
			else
				out.push(item)
			end
		}
		
		out = out.join("/")
		
		while (out.include?("//"))
			out.gsub!("//", "/")
		end
		
		replace(out)
	end
end

class GasLang
	HEADER_EXTENSIONS = [".h"]
	EXTENSIONS = [".asm"]
	OBJECT_EXTENSIONS = lambda{|mode| [".asm#{mode}o"] }
	
	def initialize()
		@gpp = "gcc"
		@gas = "#{@gpp} -x assembler"
	end
	
	def is_source(path)
		EXTENSIONS.each{|ext|
			if (path.ends_with(ext))
				return true
			end
		}
		
		return false
	end
	
	def is_object(path, mode)
		OBJECT_EXTENSIONS.call(mode).each{|ext|
			if (path.ends_with(ext))
				return true
			end
		}
		
		return false
	end
	
	def compile_deps(to_check, mode)
		# All the files that can change this one
		out = Array.new
		
		# And all the files we must process
		stack = Array.new
		stack.push(to_check)
		
		# As well as every file it includes (recursively)
		while (stack.size > 0)
			# Processes a new file
			current = stack.pop
			current_path = current.split("/")[0..-2].join("/")
			
			# This entry is a dependency
			out.push(current)
			
			file = File.new(current, "r")
			
			while (read = file.gets)
				read.strip!
				
				if (read.starts_with("#include \""))
					new = read.chomp_front("#include \"")
					new.chomp!("\"")
					new.strip!
					new = "#{current_path}/#{new}"
					new.path_clean!
					
					if !(out.include?(new) || stack.include?(new))
						stack.push(new)
					end
				end
			end
		end
		
		# Doesn't like circular dependencies
		HEADER_EXTENSIONS.each{|ext|
			if (to_check.ends_with(ext))
				out.delete(to_check)
			end
		}
		
		# All deps have been processed
		return out
	end
	
	def compile(source, deps, options, mode)
		# We don't compile headers
		HEADER_EXTENSIONS.each{|ext|
			if (source.ends_with(ext))
				return Array.new
			end
		}
		
		out = Array.new
		out.push("#{@gas} #{options.join(" ")} -c #{source.inspect} -o #{"#{source}#{mode}o".inspect}")
		
		return out
	end
	
	def compile_clean(source, deps, options, mode)
		# We don't compile headers
		HEADER_EXTENSIONS.each{|ext|
			if (source.ends_with(ext))
				return Array.new
			end
		}
		
		out = Array.new
		out.push("#{source}#{mode}o")
		
		return out
	end
	
	def compile_object(source, mode)
		# We don't compile headers
		HEADER_EXTENSIONS.each{|ext|
			if (source.ends_with(ext))
				return source
			end
		}
		
		return "#{source}#{mode}o"
	end
	
	def to_link(source, deps, options, mode)
		return compile_clean(source, deps, options, mode)
	end
	
	def link_deps(source, deps, options, mode)
		return compile_clean(source, deps, options, mode)
	end
	
	def compile_more(source, deps, options)
		out = Array.new
		
		compile_deps(source, nil).each{|item|
			if (item != source)
				HEADER_EXTENSIONS.each{|ext|
					if (File.exists?("#{item.chomp(ext)}.asm"))
						out.push("#{item.chomp(ext)}.asm")
					end
				}
				
				out.push(item)
			end
		}
		
		return out
	end
	
	def link(target, deps, options, objects, mode)
		out = Array.new
		out.push("#{@gpp} #{options.join(" ")} #{objects.map{|o| o.inspect}.join(" ")} -o #{target}")
		
		return out
	end
	
	def link_clean(target, deps, options, objects)
		out = Array.new
		out.push(target)
		
		return out
	end
end

@@languages["gas"] = GasLang