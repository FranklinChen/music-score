
{-# LANGUAGE
    TypeFamilies,
    DeriveFunctor,
    DeriveFoldable,
    FlexibleInstances,
    GeneralizedNewtypeDeriving #-}

-------------------------------------------------------------------------------------
-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides the 'Track' type.
--
-------------------------------------------------------------------------------------

module Music.Score.Track (
        Track,
        track,
  ) where

import Data.Semigroup
import Control.Applicative
import Control.Monad            (ap, join, MonadPlus(..))

import Data.Foldable            (Foldable(..), foldMap)
import Data.Pointed
import Data.Ord                 (comparing)
import Data.Function            (on)
import Data.VectorSpace
import Data.AffineSpace
import Data.AffineSpace.Point
import Test.QuickCheck          (Arbitrary(..), Gen(..))

import Music.Time
import Music.Pitch.Literal
import Music.Dynamics.Literal   

import qualified Data.List as List

-------------------------------------------------------------------------------------
-- Track type
-------------------------------------------------------------------------------------

-- |
-- A track is a list of events with explicit onset. Events can not overlap.
--
-- Track is a 'Monoid' under parallel composition. 'mempty' is the empty track and 'mappend'
-- interleaves values.
--
-- Track has an 'Applicative' instance derived from the 'Monad' instance.
--
-- Track is a 'Monad'. 'return' creates a track containing a single value at time
-- zero, and '>>=' transforms the values of a track, allowing the addition and
-- removal of values relative to the time of the value. Perhaps more intuitively,
-- 'join' delays each inner track to start at the offset of an outer track, then
-- removes the intermediate structure.
--
-- > let t = Track [(0, 65),(1, 66)]
-- >
-- > t >>= \x -> Track [(0, 'a'), (10, toEnum x)]
-- >
-- >   ==> Track {getTrack = [ (0.0,  'a'),
-- >                           (1.0,  'a'),
-- >                           (10.0, 'A'),
-- >                           (11.0, 'B') ]}
--
-- Track is an instance of 'VectorSpace' using parallel composition as addition,
-- and time scaling as scalar multiplication.
--
newtype Track a = Track { getTrack :: [(TimeT, a)] }
    deriving (Eq, Ord, Show, Functor, Foldable)

type instance Duration (Track a) = DurationT
type instance Event (Track a) = a

track :: Real t => [(t, a)] -> Track a
track = Track . fmap (first (P . fromRational . toRational))

instance Semigroup (Track a) where
    (<>) = mappend

-- Equivalent to the derived Monoid, except for the sorted invariant.
instance Monoid (Track a) where
    mempty = Track []
    Track as `mappend` Track bs = Track (as `m` bs)
        where
            m = mergeBy (comparing fst)

instance Monad Track where
    return a = Track [(origin, a)]
    a >>= k = join' . fmap k $ a
        where
            join' (Track ts) = foldMap (uncurry delay') ts

instance Applicative Track where
    pure  = return
    (<*>) = ap

instance Alternative Track where
    empty = mempty
    (<|>) = mappend

-- Satisfies left distribution
instance MonadPlus Track where
    mzero = mempty
    mplus = mappend

instance HasOnset (Track a) where
    onset (Track a) = list origin (on . head) a where on (t,x) = t

instance Delayable (Track a) where
    d `delay` Track a = Track $ fmap (first (.+^ d)) $ a

instance Stretchable (Track a) where
    d `stretch` Track a = Track $ fmap (first (d*.)) $ a

{-
instance HasOffset (Track) where
    offset (Track []) = 0
    offset (Track xs) = maximum (fmap off xs) where off  (t,x) = t
-}

--    offset x = maximum (fmap off x)   where off (t,x) = t

{-
instance HasDuration (Track) where
    duration x = offset x .-. onset x
-}

instance Arbitrary a => Arbitrary (Track a) where
    arbitrary = do
        x <- arbitrary
        t <- fmap (fromRational . toRational) $ (arbitrary::Gen Double)
        d <- fmap (fromRational . toRational) $ (arbitrary::Gen Double)
        return $ delay t $ stretch d $ (return x)



-------------------------------------------------------------------------------------

delay' t = delay (t .-. origin)

list z f [] = z
list z f xs = f xs

first f (x,y)  = (f x, y)
second f (x,y) = (x, f y)


mergeBy :: (a -> a -> Ordering) -> [a] -> [a] -> [a]
mergeBy f as bs = List.sortBy f $ as <> bs

