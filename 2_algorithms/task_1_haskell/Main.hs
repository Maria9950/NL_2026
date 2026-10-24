import Control.Monad (foldM)
import Data.Char (isDigit, isSpace)
import Data.List (dropWhileEnd, intercalate)
import System.Exit (exitFailure)
import System.IO

partitions :: Integer -> Integer -> [[Integer]]
partitions 0 _ = [[]]
partitions remaining limit =
  [ k : rest
  | k <- [m, m - 1 .. 1]
  , rest <- partitions (remaining - k) k
  ]
  where
    m = min remaining limit

classify :: Integer -> Either String Integer
classify n
  | n > 0 = Right n
  | n == 0 = Left "Ошибка: число должно быть положительным, а введён ноль."
  | otherwise = Left "Ошибка: число должно быть положительным, а введено отрицательное."

isDecimal :: String -> Bool
isDecimal s =
  case span isDigit (dropSign s) of
    (a, c : d) -> not (null a) && c `elem` ".," && not (null d) && all isDigit d
    _ -> False
  where
    dropSign ('-' : r) = r
    dropSign ('+' : r) = r
    dropSign r = r

parseInput :: String -> Either String Integer
parseInput raw
  | null t = Left "Ошибка: ввод пуст, нужно положительное целое число."
  | all isDigit t = classify (read t)
  | ('-' : ds) <- t, digits ds = classify (negate (read ds))
  | ('+' : ds) <- t, digits ds = classify (read ds)
  | isDecimal t = Left "Ошибка: введено дробное число, нужно целое."
  | otherwise = Left ("Ошибка: \"" ++ t ++ "\" не является целым числом.")
  where
    t = dropWhileEnd isSpace (dropWhile isSpace raw)
    digits ds = not (null ds) && all isDigit ds

main :: IO ()
main = do
  hSetEncoding stdin utf8
  hSetEncoding stdout utf8
  putStrLn "Введите положительное целое число n:"
  eof <- isEOF
  line <- if eof then return "" else getLine
  case parseInput line of
    Left message -> putStrLn message >> exitFailure
    Right n -> do
      count <- foldM step (0 :: Integer) (partitions n n)
      putStrLn ("Количество разбиений: " ++ show count)
  where
    step c p = do
      putStrLn (intercalate " + " (map show p))
      return $! c + 1