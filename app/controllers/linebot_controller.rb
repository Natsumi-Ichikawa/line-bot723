class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'
  require 'date'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each { |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          url  = "https://www.drk7.jp/weather/xml/13.xml"
          xml  = open( url ).read.toutf8
          doc = REXML::Document.new(xml)
          xpath = 'weatherforecast/pref/area[4]/'
          # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
          min_per = 30
          case input
            # 「明日」or「あした」というワードが含まれる場合
          when /.*(明日|あした).*/
            # info[2]：明日の天気
            per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
            per12to18 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
            per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明日の天気だよね。\n明日は雨が降りそうだよ。\n今のところ降水確率はこんな感じだよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            else
              push =
                "明日の天気？\n明日は雨が降らない予定だよ。\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね！"
            end
          when /.*(明後日|あさって).*/
            per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              push =
                "明後日の天気だよね。\n明後日は雨が降りそう…\n当日の朝に雨が降りそうだったら教えるからね！"
            else
              push =
                "明後日の天気？\n明後日は雨は降らない予定だよ(^^)\nまた当日の朝の最新の天気予報で雨が降りそうだったら教えるからね！"
            end
          when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
            push =
              "ありがとう！"
          when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
            d = Date.today.wday
            word0 = ["日","月","火","水","木","金","土"]
            word1 = ["ごみ出しなし","ミックスペーパー","段ボール","燃えるごみ","プラごみ","びんかんペット電池","燃えるごみ"]
            word4 = ["もとまちユニオンは青果朝市と卵98円（1000円以上購入)だよ。","もとまちユニオンはポイント５倍、野菜果物が98円均一だよ。",
            "今日は横浜校でバイトだね。もとまちユニオンでアイス3割引、野菜果物98円均一だよ。","今日はもとまちユニオンで卵が100円だよ。", 
            "もとまちユニオンはヨーグルト１割引だよ。","今日はセンター南校でバイトだね。もとまちユニオンで野菜果物がポイント５倍だよ。",
            "もとまちユニオンで精肉ジャンボパックが安いよ。"]
            luckyitems = ["ラーメン","帽子","チョコレート","枕","お風呂","メガネ","犬",
            "ねこ","しりとり","クリームシチュー","冷やし中華","カキフライ","リュック","大福",
            "瞬足","埼玉","流体力学","ラズパイ","しいたけ","群馬","コップ","靴下","ストレッチポール","ウエハース"].sample
            push =
              "こんにちは。\n今日は#{word0[d]}曜日、#{word1[d]}の日だよ。#{word4[d]}　\nラッキーアイテムは#{luckyitems}だよ！"
          else
            per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]l'].text
            per12to18 = doc.elements[xpath + 'info/rainfallchance/period[3]l'].text
            per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]l'].text
            if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
              word =
                ["雨だけど元気出していこうね！",
                 "雨に負けずファイト！！"].sample
              push =
                "今日の天気？\n今日は雨が降りそうだから傘があった方が安心だよ。\n　  6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word}"
            else
              word =
                ["天気もいいから一駅歩いてみるのはどう？(^^)",
                 "素晴らしい一日になりますように(^^)",
                 "雨が降っちゃったらごめんね(><)"].sample
              push =
                "今日の天気？\n今日は雨は降らなさそうだよ。\n#{word}"
            end
          end
          # テキスト以外（画像等）のメッセージが送られた場合
        else
          push = "テキスト以外はわからないよ〜(；；)"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end