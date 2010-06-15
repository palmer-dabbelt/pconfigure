class String
	def starts_with(other)
		if (self.size < other.size)
			return false
		else
			return self[0 .. (other.size - 1)] == other[0 .. (other.size - 1)]
		end
	end
	
	def chomp_front!(other)
		replace(chomp_front(other))
	end
	
	def chomp_front(other)
		return self.reverse.chomp(other.reverse).reverse
	end
end

class RubyLang
	def initialize()
		@prbc = "prbc"
	end
	
	def is_source(path)
		return path.split(".")[-1] == "rb"
	end
	
	def is_object(path, u)
		return is_source(path)
	end
	
	def compile_deps(to_check)
		out = Array.new
		stack = Array.new
		stack.push(to_check)
		
		while (stack.size > 0)
			cur = stack.pop
			out.push(cur)
			
			path = "#{cur.split("/")[0..-2].join("/")}"
			
			file = File.new(cur, "r")
			while (read = file.gets)
				read.strip!
				
				if (read.starts_with("require"))
					new = read.chomp_front("require")
					new.strip!
					new.chomp_front!("(")
					new.chomp!(")")
					new.strip!
					new.chomp_front!("\"")
					new.chomp!("\"")
					new.chomp_front!("'")
					new.chomp!("'")
					
					new = "#{path}/#{new}"
					if (File.exists?(new))
						stack.push(new)
					end
				end
			end
		end
		
		out.delete(to_check)
		return out
	end
	
	def compile(source, deps, options, u)
		return Array.new
	end
	
	def compile_clean(source, deps, options, u)
		return Array.new
	end
	
	def compile_object(source, u)
		return source
	end
	
	def to_link(source, deps, options, u)
		out = Array.new
		
		out.push(source)
		
		return out
	end
	
	def link_deps(source, deps, options, u)
		out = compile_deps(source)
		
		out.push(source)
		
		return out
	end
	
	def compile_more(source, deps, options)
		return Array.new
	end
	
	def link(target, deps, options, objects, u)
		out = Array.new
		
		out.push("#{@prbc} #{objects.join(" ")} -o #{target}")
		
		return out
	end
	
	def link_clean(target, deps, options, objects)
		out = Array.new
		
		out.push("#{target}")
		
		return out
	end
end

@@languages["ruby"] = RubyLang

