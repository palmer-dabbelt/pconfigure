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

class MocLang
	EXTENSIONS = [".moc"]
	
	def initialize()
		@moc = "moc"
	end
	
	def is_source(path)
		return path.ends_with(".moc")
	end
	
	def is_object(path, mode)
		return false
	end
	
	def compile_deps(to_check, mode)
		out = Array.new
		out.push("#{to_check.chomp(".moc")}.h++")
		return out
	end
	
	def compile(source, deps, options, mode)
		hdrdir = @@hdrdir
		if (@@pconfopts_hdrchomp == true)
			hdrdir = hdrdir.split("/")[0..-2].join("/")
		end
		
		out = Array.new
		out.push("#{@moc} -I#{hdrdir} #{options.join(" ").gsub("-Wall", "").gsub("-Werror", "").gsub("-g", "")} #{source.chomp(".moc")}.h++ -o #{source.chomp(".moc")}.moc")
		
		return out
	end
	
	def compile_clean(source, deps, options, mode)
		out = Array.new
		out.push("#{source.chomp(".moc")}.moc")
		return out
	end
	
	def compile_object(source, mode)
		return "#{source.chomp(".moc")}.moc"
	end
	
	def to_link(source, deps, options, mode)
		return Array.new
	end
	
	def link_deps(source, deps, options, mode)
		return Array.new
	end
	
	def compile_more(source, deps, options)
		return Array.new
	end
	
	def link(target, deps, options, objects, mode)
		return Array.new
	end
	
	def link_clean(target, deps, options, objects)
		return Array.new
	end
end

@@languages["moc"] = MocLang
