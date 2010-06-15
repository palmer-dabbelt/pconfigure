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

# Parses the arguments
@@inputs = Array.new
@@output = Array.new

argv_parse = @@inputs
ARGV.each{|arg|
	if (arg == "-o")
		argv_parse = @@output
	else
		argv_parse.push(arg)
		argv_parse = @@inputs
	end
}
output = File.new(@@output[0], "w")

# Counts the processed 
@@inputs.each{|input|
	stack = Array.new
	path_stack = Array.new
	stack.push(File.new(input, "r"))
	path_stack.push(input)
	
	while (stack.size > 0)
		if (read = stack[-1].gets)
			read.chomp
			
			if (read.strip != "")
				if (read.strip.starts_with("#include \""))
					new = read.chomp_front("#include \"")
					new.strip!
					new.chomp!("\"")
					new.strip!
					
					new = "#{path_stack[-1].split("/")[0..-2].join("/")}/#{new}"
					if (File.exists?(new))
						path_stack.push(new)
						stack.push(File.new(new, "r"))
						
						output.puts("/*#{new}*/")
					else
						output.puts(read)
					end
				else
					output.puts(read)
				end
			end
		else
			stack.pop.close
			path_stack.pop
		end
	end
}

output.close

