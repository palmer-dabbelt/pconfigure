class String
	def path_fix()
		out = "#{self.to_s}"
		
		while (out.include?("//"))
			out.gsub!("//", "/")
		end
		
		return out
	end
end
