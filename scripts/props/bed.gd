extends Interactable
## Home bed: sleep to end the day (advances the day, refreshes leads/prospects, autosaves).


func interact(_player: Node) -> void:
	UIEvents.ask("Go to sleep?",
		"End [b]Day %d[/b] and wake up tomorrow at 08:30 AM.\nNew leads arrive overnight. The game autosaves." % GameState.day,
		[UIEvents.option("Sleep", GameState.sleep, false, true), UIEvents.option("Not now")])
