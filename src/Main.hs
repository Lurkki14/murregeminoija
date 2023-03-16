{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

import Control.Applicative
import Control.Monad
import Data.Char as T
import Data.Map.Strict hiding (foldr, filter, lookup, singleton)
import qualified Data.Map.Strict as M
import Data.Maybe
import qualified Data.Set as Set
import Data.Text.Encoding
import Data.Text hiding (head, foldr, zip, words)
import qualified Data.Text as T
import qualified Data.Text.IO as T.IO
import Options.Applicative
import Text.Read

import Gemination
import Epenthesis

-- Program options
data Input =
  File FilePath |
  StdIn |
  Interactive deriving (Show)

data Feature =
  CommonGemination |
  SpecialGemination |
  Epenthesis deriving (Read, Show)

data Options = Options {
  inputOpt :: Input,
  featuresOpt :: [Feature]
} deriving (Show)

data FeatureInfo = FeatureInfo {
  feature :: Feature,
  function :: Text -> Maybe Text,
  -- Throw error if one of these appears in the same list
  -- Or: valid list can't be created if in same list
  conflicts :: [Feature],
  -- Any instance of these is removed if in the same list
  supersetOf :: [Feature]
}

type Transformation = (Text -> Text)

-- Language features
-- Associate all these with LangWord -> Maybe Text (Maybe because replacing is expensive)
-- We also might need to model dependencies and conflicts
data PhonologicalFeatures = PhonologicalFeatures {
  commonGemination :: Bool,
  specialGemination :: Bool,
  epenthesis :: Bool -- https://kaino.kotus.fi/visk/sisallys.php?p=33
}

featureInfo :: [FeatureInfo]
featureInfo =
  [
    FeatureInfo CommonGemination commonGeminated [] [],
    FeatureInfo Epenthesis applyEpenthesis [] [],
    FeatureInfo SpecialGemination applySpecialGemination [] [CommonGemination],
    FeatureInfo PohjanmaaEpenthesis applyPohjanmaaEpenthesis [] [Epenthesis]
  ]

featureInfoMap = fromList $ fmap (\info -> (,) info.feature info) featureInfo

input :: Parser Input
input = file <|> stdIn <|> interactive where
  file = File <$> strOption (
    long "file" <>
    short 'f' )
  stdIn = flag' StdIn (
    long "stdin" <>
    short 's' )
  interactive = flag' Interactive (
    long "interactive" <>
    short 'i' )

features :: Parser [Feature]
features = option parseFeatures (
  long "features" <>
  short 'F' ) where
    parseFeatures :: ReadM [Feature]
    parseFeatures = eitherReader readFeaturesE
    readFeaturesE :: String -> Either String [Feature]
    readFeaturesE string =
      case readFeatures string of (Just xs) -> Right xs
                                  Nothing -> Left "No such feature name"
    -- Parse a comma separated list of Features
    readFeatures :: String -> Maybe [Feature]
    readFeatures string = mapM readMaybe strings where
      strings :: [String]
      strings = fmap unpack $ splitOn "," $ pack string

optionsP :: Parser Options
optionsP = Options <$> input <*> features

options :: ParserInfo Options
options = info (optionsP <**> helper) mempty

transformations = [ commonGeminated, applyEpenthesis ] :: [Text -> Maybe Text]

transformationsPlain = fmap (ap fromMaybe) transformations :: [Text -> Text]

thread :: Foldable t => t (a -> a) -> a -> a
thread = foldr (.) id

-- Return Maybe Text so we don't try to replace every word,
-- whether they've been modified or not
transform :: [Transformation] -> Text -> Maybe Text
transform fs word
  | transformed == word = Nothing
  | otherwise = Just transformed where
    transformed = thread fs word

replacements :: [Transformation] -> Text -> [(Text, Text)]
replacements fs text = [ (orig, mod) | (orig, Just mod) <- zip words transformed ] where
  words = T.words text
  transformed = fmap (transform fs) words

transformText :: [Transformation] -> Text -> Text
transformText fs text =
  foldr (\(orig, mod) acc -> replace orig mod acc) text $ replacements fs text

interactiveLoop :: Options -> IO ()
interactiveLoop opts =
  T.IO.getLine >>=
    T.IO.putStrLn . ("-> " <>) . transformText (fromFeatures opts.featuresOpt) >>
      interactiveLoop opts

fromFeatures :: [Feature] -> [Transformation]
fromFeatures features =
  (\(k, featureInfo) -> ap fromMaybe featureInfo.function) <$>
    M.toList withoutSubsets where
      mapWithFeatures = M.restrictKeys featureInfoMap $ Set.fromList features
      withoutSubsets =
        foldr (\feature acc -> removeSubsets acc feature) mapWithFeatures features
      removeSubsets :: Map Feature FeatureInfo -> Feature -> Map Feature FeatureInfo
      removeSubsets map feature = fromMaybe map $ M.lookup feature map >>= \v ->
        pure $ foldr delete map v.supersetOf
      -- TODO: remove conflicting features

main = do
  options <- execParser options
  doMain options where
    doMain :: Options -> IO ()
    doMain options@Options {inputOpt = Interactive} =
      T.IO.putStrLn "Enter a line of text: " >>
        interactiveLoop options
    doMain Options {inputOpt = StdIn} = pure () -- TODO: do something :D
    doMain Options {inputOpt = (File filePath), featuresOpt} =
      T.IO.readFile filePath >>= T.IO.putStr . transformText (fromFeatures featuresOpt)
