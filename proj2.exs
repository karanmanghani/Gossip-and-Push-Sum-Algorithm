defmodule Caller do
	def exec do
		Project.start([String.to_integer(Enum.at(System.argv(), 0)), Enum.at(System.argv(), 1), Enum.at(System.argv(), 2)])
	end
end
Caller.exec
