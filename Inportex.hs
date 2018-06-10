import Data.Char -- toLower
import Data.String.Utils -- replace
import Text.Printf -- printf
import Text.Regex.PCRE
import Network.HTTP
import System

-- начало программы
main = do
  args <- getArgs  -- получили аргументы
  parseArgs args  -- обрабатываем их
  
-- проверяем количество аргументов и выводим usage;
parseArgs :: [String] -> IO ()

-- если число аргументов - два или больше:
parseArgs (url:outFile:xs) = do
  let xmlUrl = urlToXmlUrl url
  xmlData <- httpGet xmlUrl
  let cmd = genCmd (xmlToRtmpUrl xmlData) outFile
  if cmd == "" then do
    putStrLn $ "Failed to parse url!"
    exitWith $ ExitFailure 1
  else do
    putStrLn $ "cmd: " ++ cmd
    exitCode <- system cmd
    putStrLn $ "rtmpdump terminated, exit code = " ++
               show exitCode
  
-- если передано меньше двух аргументов
parseArgs _ = do
  progName <- getProgName
  putStrLn $ "Usage: " ++ progName ++ " <url> <outfile>"
  exitWith $ ExitFailure 2
  
-- скачиваем заданную страницу
httpGet :: String -> IO(String)
httpGet "" = do
  return ""
httpGet url = do 
  query <- simpleHTTP (getRequest url)
  body <- getResponseBody query
  return body

-- преборазуем rtmp-ссылку и имя выходного файла в команду
genCmd :: String -> String -> String
genCmd rtmpUrl outFile =
  let regex = "(?i)^(rtmp://[^\"/]+/)([^\"]*?/)(mp4:[^\"]*)$"
      match = rtmpUrl =~ regex :: [[String]]
  in case match of
    [[_, rtmp, app, playPath]] ->
      let live = if app == "vod/" then " --live" else ""
          -- кавычка - нормальная часть имени
          outFile' = replace "\"" "\\\"" outFile in
      -- на самом деле ничего не выводим, как sprintf в сях
      printf ( "rtmpdump --rtmp \"%s\" --app \"%s\" --playpath \"%s\""
        ++ " --swfUrl http://rutube.ru/player.swf --flv \"%s\"%s" )
        rtmp app playPath outFile live
    _ -> ""

-- выдираем rtmp-ссылку из xml файла
xmlToRtmpUrl :: String -> String
xmlToRtmpUrl xml =
  let regex = "(?i)<!\\[CDATA\\[(rtmp://[^\\]]+)\\]\\]>"
      match = xml =~ regex :: [[String]]
  in case match of
    [] -> ""
    [[_, rtmpUrl]] -> rtmpUrl

-- преобразование ссылки на видео в ссылку на xml
urlToXmlUrl :: String -> String 
urlToXmlUrl url =
  let regex="(?i)^(?:http://)?rutube\\.ru/.*?[\\?&]{1}v=([a-f\\d]{32})"
      match = url =~ regex :: [[String]]
  in case match of
    [] -> ""
    [[_, hash]] -> "http://bl.rutube.ru/" ++ map toLower hash ++ ".xml"
