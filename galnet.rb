require 'selenium-webdriver'
require 'date'
require 'pg'

SAVE_DIR = 'extracted'

def extract(driver)
  driver.navigate.to("https://community.elitedangerous.com/galnet")
  links = driver.find_elements(class: 'galnetLinkBoxLink').map do |link|
    href = link.attribute(:href)
    puts "collecting #{href}"
    href
  end
  links.each do |link|
    driver.navigate.to(link)
    extract_articles(driver)
  end
end

def extract_articles(driver)
  count = 1
  driver.find_elements(class: 'article').each do |article|
    extract_article(driver, article, count)
    count += 1
  end
end

def extract_article(driver, article, count)
  title = article.find_element(class: 'galnetNewsArticleTitle').text
  date = article.find_element(class: 'i_right').text
  body = article.find_elements(tag_name: 'p').last.text

  begin
    date = Date.parse(date)
  rescue ArgumentError => e
    # This should be the only invalid date.
    if date == "29 FEB 3302"
      date = "3302-02-29"
    else
      raise e
    end
  end

  ascii_quotes(title)
  ascii_quotes(body)

  write_file(title, date, body, count)

  # TODO: Better galos integration.
  # insert_article(title, date, body)
end

def ascii_quotes(text)
  text.gsub!(/[”“]/, '"')
  text.gsub!(/[‘’]/, "'")
end

def write_file(title, date, body, count = 1)
  FileUtils.mkdir_p(SAVE_DIR)

  contents = ""
  unless title.strip.empty?
    contents += "#{title}\n"
  end
  contents += "#{date}\n"
  contents += "#{'=' * 65}\n\n"
  contents += body

  filename = if count == 1 then date.to_s else "#{date}-#{count}" end
  File.write(File.join(SAVE_DIR, filename), contents)
end

def insert_article(title, date, body)
  begin
    conn = PG.connect(dbname: 'elite_development')
    conn.prepare("insert", "INSERT INTO articles (title, date, body) VALUES($1, $2, $3)")
    result = conn.exec_prepared("insert", [title, date, body])
  rescue PG::Error => e
    puts e.message
  ensure
    conn.close if conn
  end
end

driver = Selenium::WebDriver.for :chrome
extract(driver)
driver.quit

