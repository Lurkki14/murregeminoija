{-# LANGUAGE OverloadedStrings #-}

import Data.Maybe
import qualified Data.Text as T
import qualified Data.Text.IO as T.IO

data MaybeShort = CV T.Text | V T.Text deriving (Show) 
-- this kind of syllable is applicable for common gemination
data LongOpen = CVV T.Text | CDD T.Text deriving (Show) 
data Syllable = MaybeShort | LongOpen | LongOther
data CommonGeminable = CommonGeminable {
  first :: MaybeShort,
  second :: LongOpen,
  tail :: T.Text
}

-- Other vowel combinations aren't considered diphthongs and will break a syllable (eg. ta-e)
-- TODO: replace these with data structures that are more efficient to search
diphthongs = [ "ei", "öi", "äi", "oi", "ai", "ey", "öy",
  "äy", "eu", "ou", "au", "yi", "ui", "iy", "iu" ] :: [T.Text] 

consonants = [ "b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x" ] :: [T.Text]

vowels = [ "a", "e", "i", "o", "u", "y", "ä", "ö" ] :: [T.Text]

parseMaybeShort :: T.Text -> Maybe MaybeShort
parseMaybeShort x
  | isJust $ parseV x = parseV x
  | otherwise = parseCV x where
  parseV x
    | elem (T.take 1 x) vowels = Just $ V x
    | otherwise = Nothing
  parseCV x
    | (elem (T.take 1 x) consonants) && (elem (T.drop 1 x) vowels) = Just $ CV x
    | otherwise = Nothing

parseLongOpen :: T.Text -> Maybe LongOpen
parseLongOpen x
  | not $ elem consonantCandidate consonants = Nothing
  | isJust parsedVV = parsedVV
  | otherwise = parsedDD where
  consonantCandidate = T.take 1 x
  vvddCandidate = T.drop 1 $ T.take 3 x
  parsedVV = parseLongVowel vvddCandidate >>= \vv -> Just $ CVV $ T.append consonantCandidate vv
  parsedDD = parseDiphthong vvddCandidate >>= \dd -> Just $ CDD $ T.append consonantCandidate dd

-- For "general gemination" we need to know if:
-- 1. The preceding syllable is short (CV or V)
-- 2. Whether the preceding syllable stressed (first)
-- 3. If the second syllable is of the form (CVV or CDD*) *D = part of a diphthong
-- In short, 'CVCDD, 'CVCVV, 'VCDD, 'VCVV are applicable

parseDiphthong :: T.Text -> Maybe T.Text
parseDiphthong x
  | T.length candidate /= 2 = Nothing
  | not $ elem candidate diphthongs = Nothing
  | elem candidate diphthongs = Just x
  where candidate = T.take 2 x -- Text.take is O(n) so don't waste time calculating the length of a big string

parseLongVowel :: T.Text -> Maybe T.Text
parseLongVowel x
  | bothSame candidate && elem (T.take 1 x) vowels = Just x
  | otherwise = Nothing where
  bothSame x = T.take 1 x == T.drop 1 x
  candidate = T.take 2 x

maybeShort = CV "ak"
longOpen = CVV "taa"

main = do
  input <- T.IO.getContents
  --T.IO.putStrLn $ fromMaybe "Not a diphthong" (parseDiphthong input)
  --T.IO.putStrLn $ fromMaybe maybeShort (parseMaybeShort "ta")
  print $ fromMaybe maybeShort (parseMaybeShort "ta")
  print $ fromMaybe longOpen (parseLongOpen "sau")
