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

# Starts with the scheme header
output.puts("#!#{`which mzscheme`.strip}")
output.puts("#lang scheme/base")
output.puts("")

# Cats every input file, in order
@@inputs.each{|filename|
	input = File.new(filename, "r")
	
	while (read = input.gets)
		output.write(read)
	end
	
	input.close
}

output.close
`chmod +x "#{@@output[0]}"`

