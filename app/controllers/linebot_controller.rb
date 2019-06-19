class LinebotController < ApplicationController
    require 'line/bot'  # gem 'line-bot-api'
    require "json"
    require "open-uri"
    require "date"
    API_KEY = "94ba2db12c3a322b709522ebe910ec6b"
    BASE_URL = "http://api.openweathermap.org/data/2.5/forecast"
    nowTime = DateTime.now

    # callbackアクションのCSRFトークン認証を無効
    protect_from_forgery :except => [:callback]

    def callback
      body = request.body.read

      signature = request.env['HTTP_X_LINE_SIGNATURE']
      unless client.validate_signature(body, signature)
        head :bad_request
      end

      events = client.parse_events_from(body)

      events.each { |event|
        case event
        when Line::Bot::Event::Message
          case event.type
          when Line::Bot::Event::MessageType::Text
            message = event.message['text']
            if send_msg(message)
                message = change_msg(msg)
                result_msg = msg.join
                client.reply_message(event['replyToken'], {
                    type: 'text',
                    text: result_msg
                });
            else
                client.reply_message(event['replyToken'], {
                    type: 'text',
                    text: message
                });
            end
          end
        end
      }
      head :ok
    end
    
    def send_msg(msg)
        if msg == "東京"
            return true
        else
            return false
        end
    end
    
    def change_msg(msg)
        case msg
        when "東京"
            response = open(BASE_URL + "?q=Tokyo,jp&APPID=#{API_KEY}")
            data = JSON.parse(response.read, {symbolize_names: true})
            result = weather_text(data)
            return result
        end
    end
    
    def weather_text(weather_data)
      item = weather_data[:list]
      result = Array.new
      forecastCityname = weather_data[:city][:name]
      (0..7).each do |i|
        forecastDatetime = item[i][:dt_txt]
        forecasttemp = (item[i][:main][:temp] - 273.15).round(1)
        weather_id = item[i][:weather][0][:id]
        weather = get_weather(weather_id)
        result[i] = "#{forecastCityname}の天気をお知らせします。\n#{forecastDatetime}の天気は#{weather}\n温度は#{forecasttemp}\n"
      end
      return result
    end
    
    def get_weather(weather_id)
      case weather_id
      when 200, 201, 202, 210, 211, 212, 221, 230, 231, 232, 
        300, 301, 302, 310, 311, 312, 313, 314, 321, 
        500, 501, 502, 503, 504, 511, 520, 521, 522, 523 ,531 then
        weather = '雨'
        return weather
      when 601, 602, 611, 612, 615, 616, 620, 621, 622 then
        weather = '雪'
        return weather
      when 701, 711, 721, 731, 741, 751, 761, 762, 771, 781 then
        weather = '異常気象'
        return weather
      when 800 then
        weather = '晴れ'
        return weather
      when 801, 802, 803, 804 then
        weather = '曇り'
        return weather
      else
        weather = '不明'
        return weather
      end
    end
    
    private 
    def client
      @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
      }
    end
end
