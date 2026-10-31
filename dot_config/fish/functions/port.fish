function port --description 'Show process listening on a TCP/UDP port'
	if test (count $argv) -eq 0
		echo 'Error: Please provide a port (e.g., 3000)'
		return 1
	end
	lsof -i:$argv[1]
end
