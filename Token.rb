class Token < String
	def initialize(string="")
		@str = string
	end
	
	def to_s
	  return @str
  end
  
	def next_token(delim=" ")
		tokens = @str.strip.downcase.split(delim)
		if (tokens[0]) then
		  command = tokens[0]
		  @str = tokens[1..tokens.size-1].join(delim)
		  return command
	  end
	  return nil
	end
	
	def last_token(delim=" ")
		tokens = @str.strip.downcase.split(delim)
		if (tokens[-1]) then
		  command = tokens[-1]
		  @str = tokens[0..tokens.size-2].join(delim)
		  return command
	  end
	  return nil
	end

	def predicate
	  return @str
  end
end
