require 'migrate/migrate'

class MigrateQuestion < Migrate
  def migrate_question(filepath = "./../ccdata.xls")
    s = Roo::Excel.new(filepath)
    question_sheet = s.sheet(0)
    spreadsheet_to_question_attributes = { "id"=>"id", "Question"=>"display_text", "Original Question"=>"original_text", "Neighborhood"=>"neighbourhood", "Name"=>"name", "Email"=>"email", "Anonymous"=>"anonymous", "Image Attribution"=>"picture_attribution_url", "Image Username"=>"picture_owner", "Reporter"=>"reporter" }
    column_indices_names = spreadsheet_to_question_attributes.keys.push("Badge").push("Approved").push("Categories").push("Date Uploaded").push("Image Url").push("Response Link URL").push("Response Link Text")

    column_indices = get_spreadsheet_column_indices(column_indices_names, question_sheet)
    models = get_question_models(spreadsheet_to_question_attributes, question_sheet, column_indices)
    save_models(models)
  end

  def get_question_models(spreadsheet_to_model_attribute_names, spreadsheet, attribute_column_indices)
    i=2
    questions = []

    while !spreadsheet.cell(i, 1).nil?
      question = Question.new
      map_generic_data(spreadsheet.row(i), question, spreadsheet_to_model_attribute_names, attribute_column_indices)
      map_question_data(spreadsheet.row(i), question, attribute_column_indices)
      questions.push question
      print "."
      # print "#{i-1} "
      i+=1
    end

    return questions
  end

  def map_question_data(row, question, attribute_column_indices)
    question.email_confirmation = question.email

    anonymous_cell = row[attribute_column_indices["Anonymous"]]
    date_uploaded = row[attribute_column_indices["Date Uploaded"]]
    badge = row[attribute_column_indices["Badge"]]
    approved = row[attribute_column_indices["Approved"]]
    image_url = row[attribute_column_indices["Image Url"]]
    category_names = row[attribute_column_indices["Categories"]]
    response_link_text = row[attribute_column_indices["Response Link Text"]]
    response_link_url = row[attribute_column_indices["Response Link URL"]]

    question.anonymous = map_question_anonymous(anonymous_cell)
    question.created_at = map_question_created_at(date_uploaded)
    question.status = map_question_status(badge, approved)
    question.picture_url = map_question_image_url(image_url)
    question.categories = map_question_categories(category_names)
    question.answers = map_question_answers(response_link_text, response_link_url, question.id)
  end

  def map_question_anonymous(anonymous)
    anonymous.to_i != 0
  end

  def map_question_created_at(date_uploaded)
    Time.at(date_uploaded.to_i)
  end

  def map_question_image_url(image_url)
    row_image_url = image_url
    image_url unless ( row_image_url == "images/default.jpg")
  end

  def map_question_status(badge, approved)
    if badge == "answered"
      Question::Status::Answered
    elsif badge == "investigated"
      Question::Status::Investigating
    elsif approved == 1
      Question::Status::New
    else
      Question::Status::Removed
    end
  end

  def map_question_categories(category_names_str)
    category_names_arr = category_names_str.to_s.rstrip.split(/, |,/)
    category_names_arr.map! { |name| name.downcase.gsub(/like to/, "like").gsub(/ /, '-') }
    categories = category_names_arr.map { |name| Category.where(name: name).first }
    categories
  end

  def map_question_answers(response_link_text, response_link_url, question_id)
    if response_link_text.presence
      answer = Answer.new
      answer.type = Answer::Type::Answer
      answer.label = response_link_text
      answer.url = response_link_url
      answer.question_id = question_id
      [answer]
    else
      []
    end
  end
end
