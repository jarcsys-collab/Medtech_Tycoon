extends Interactable
## Home bed: sleep to end the day early. Shows the end-of-day summary; its NEXT DAY button starts
## the next morning (new leads and prospects, autosave).


func interact(_player: Node) -> void:
	UIEvents.ask("Go to sleep?",
		"End [b]Day %d[/b] and wake up tomorrow at 08:30 AM.\nNew leads arrive overnight. The game autosaves." % GameState.day,
		[UIEvents.option("Sleep", GameState.end_day.bind(&"sleep"), false, true), UIEvents.option("Not now")])
