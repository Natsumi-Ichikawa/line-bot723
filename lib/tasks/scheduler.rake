namespace :scheduler do
end
desc "This task is called by the Heroku scheduler add-on"
task :update_feed => :environment do
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'
  require 'date'

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  # 使用したxmlデータ（毎日朝6時更新）：以下URLを入力すれば見ることができます。
  url  = "https://www.drk7.jp/weather/xml/14.xml"
  # xmlデータをパース（利用しやすいように整形）
  xml  = open( url ).read.toutf8
  doc = REXML::Document.new(xml)
  # パスの共通部分を変数化（area[1]は「東部」を指定している）
  xpath = 'weatherforecast/pref/area[1]/info/rainfallchance/'
  # 6時〜12時の降水確率（以下同様）
  per06to12 = doc.elements[xpath + 'period[2]'].text
  per12to18 = doc.elements[xpath + 'period[3]'].text
  per18to24 = doc.elements[xpath + 'period[4]'].text
  # メッセージを発信する降水確率の下限値の設定
  min_per = 20
  d = Date.today.wday
    word0 = ["日","月","火","水","木","金","土"]
    word1 = ["ごみ出しなし","ミックスペーパー","段ボール","燃えるごみ","プラごみ","びんかんペット電池","燃えるごみ"]
    word4 = [" "," ","今日は横浜校でバイトだね。もとまちユニオンでアイスが安いよ。","今日はもとまちユニオンで卵が100円だよ。", " ","今日はセンター南校でバイトだね。"," "]
  
  word2 =
      ["気をつけて行ってきてね(^^)",
       "良い一日を過ごしてね(^^)",
       "雨に負けずに今日も頑張ってね(^^)",
       "今日も一日楽しんでいこうね(^^)",
       "楽しいことがありますように(^^)"].sample
  #ラッキーアイテムの追加
  luckyitems = ["ラーメン","帽子","チョコレート","枕","お風呂","メガネ","犬",
    "ねこ","しりとり","クリームシチュー","冷やし中華","カキフライ","リュック","大福",
    "瞬足","埼玉","流体力学","ラズパイ","しいたけ","群馬","コップ","靴下","ストレッチポール","ウエハース"].sample

    # 降水確率によってメッセージを変更する閾値の設定
    mid_per = 50
    if per06to12.to_i >= mid_per || per12to18.to_i >= mid_per || per18to24.to_i >= mid_per
      word3 = "今日は雨が降りそうだから傘を忘れないでね！"
    elsif　per06to12.to_i <= min_per && per12to18.to_i <= min_per && per18to24.to_i <= min_per
      word3 = "今日は雨は降らないよ。洗濯物を干そう！"
    else 
      word3 = "今日は雨が降るかもしれないから折りたたみ傘があると安心だよ！"
    end
    # 発信するメッセージの設定
    push =
      "おはよう！今日は#{word0[d]}曜日、#{word1[d]}の日だよ。\n#{word3}\n[降水確率]\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％
      \n#{word4[d]}今日のラッキーアイテムは#{luckyitems}だよ！\n#{word2}"
    # メッセージの発信先idを配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
    user_ids = User.all.pluck(:line_id)
    message = {
      type: 'text',
      text: push
    }
    response = client.multicast(user_ids, message)
  end
  "OK"
