function grs --description 'Soft-reset to a commit and unstage everything'
	if test (count $argv) -eq 0
		echo 'Error: Please provide a commit (e.g., HEAD~1)'
		return 1
	end
	git reset --soft $argv[1] && git restore --staged .
end
