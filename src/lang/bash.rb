class BashLang
	def initialize()
		@pbashc = "pbashc"
	end
	
	def is_source(path)
		return path.split(".")[-1] == "bash"
	end
	
	def is_object(path, u)
		return is_source(path)
	end
	
	def compile_deps(to_check)
		return Array.new
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
		
		out.push("#{@pbashc} #{objects.join(" ")} -o #{target}")
		
		return out
	end
	
	def link_clean(target, deps, options, objects)
		out = Array.new
		
		out.push("#{target}")
		
		return out
	end
end

@@languages["bash"] = BashLang

