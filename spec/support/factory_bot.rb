# Configure test suite for factory bot
# Enables creating factories with "create" rather than "FactoryBot.create" and "build" instead of "FactoryBot.build"
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  #below is quick fix for factorybot 5.x breakage
  FactoryBot.use_parent_strategy = false
end