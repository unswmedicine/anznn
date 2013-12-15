class ChangeQuestionOptionsHintTextToText < ActiveRecord::Migration
 def up
    change_table :question_options do |t|
      t.change :hint_text, :text
    end
  end
 
  def down
    change_table :question_options do |t|
      t.change :hint_text, :string
    end
  end
end
