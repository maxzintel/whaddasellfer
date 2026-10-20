namespace :game do
  desc "Delete today's puzzle and all of today's games (development/test only)"
  task reset_today: :environment do
    date = Time.zone.today
    deleted = Puzzle.reset_day!(date)
    puts "Reset #{date}: deleted the puzzle and #{deleted} game(s). The next game picks new cars."
  end

  desc "Delete every puzzle and game; listings stay (development/test only)"
  task reset_all: :environment do
    deleted = Puzzle.reset_all!
    puts "Deleted all puzzles and #{deleted} game(s). Every car is unused again."
  end
end
