class String
	def path_fix()
		out = "#{self.to_s}"
		
		while (out.include?("//"))
			out.gsub!("//", "/")
		end
		
		while (out.include?("~"))
			out.gsub!("~", `echo $HOME`.strip)
		end
		
		return out
	end
end
