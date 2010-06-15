stack = Array.new
stack.push(".")

while (stack.size > 0)
	cur = stack.pop
	
	Dir.foreach(cur){|item|
		full_path = "#{cur}/#{item}"
		
		if (item[0].chr == ".")
			# ignore hidden files
		elsif (File.directory?(full_path))
			stack.push(full_path)
		elsif (full_path[-1].chr == "~")
			File.delete(full_path)
		end
	}
end
