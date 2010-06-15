@@languages = Hash.new
@@languages_used = Array.new

class LangBase
	def LangBase.push(lang)
		@@languages_used.push(lang)
	end
	
	def LangBase.compile_deps(source, mode)
# 		puts "LangBase.compile_deps(#{source.inspect})"
		lang = LangBase.is_source(source)
		return lang.compile_deps(source, mode)
	end
	
	def LangBase.compile(source, deps, options, mode)
# 		puts "LangBase.compile(#{source.inspect})"
		lang = LangBase.is_source(source)
		return lang.compile(source, deps, options, mode)
	end
	
	def LangBase.compile_clean(source, deps, options, mode)
# 		puts "LangBase.compile_clean(#{source.inspect})"
		lang = LangBase.is_source(source)
		return lang.compile_clean(source, deps, options, mode)
	end
	
	def LangBase.to_link(source, deps, options, mode)
# 		puts "LangBase.to_link(#{source.inspect})"
		lang = LangBase.is_source(source)
		return lang.to_link(source, deps, options, mode)
	end
	
	def LangBase.link_deps(source, deps, options, mode)
# 		puts "LangBase.link_deps(#{source.inspect})"
		lang = LangBase.is_source(source)
		return lang.link_deps(source, deps, options, mode)
	end
	
	def LangBase.compile_more(source, deps, options)
# 		puts "LangBase.compile_more(#{source.inspect})"
		lang = LangBase.is_source(source)
		return lang.compile_more(source, deps, options)
	end
	
	def LangBase.link(target, deps, options, objects, mode)
# 		puts "LangBase.link(#{target.inspect})"
		lang = LangBase.are_objects(objects, mode)
		return lang.link(target, deps, options, objects, mode)
	end
	
	def LangBase.link_clean(target, deps, options, objects, mode)
# 		puts "LangBase.link_clean(#{target.inspect})"
		lang = LangBase.are_objects(objects, mode)
		return lang.link_clean(target, deps, options, objects)
	end
	
	def LangBase.compile_object(source, mode)
		lang = LangBase.is_source(source)
		return lang.compile_object(source, mode)
	end
	
	def LangBase.is_source(source)
		@@languages_used.each{|lang|
			if (lang.is_source(source))
				return lang
			end
		}
		
		puts "Could not find language for source '#{source}'"
		exit 1
	end
	
	def LangBase.are_objects(objects, mode)
		@@languages_used.each{|lang|
			good = true
			
			objects.each{|object|
				if !(lang.is_object(object, mode))
					good = false
				end
			}
			
			if (good == true)
				return lang
			end
		}
		
		puts "Cound not find language for objects #{objects.inspect}"
		exit 1
	end
end
