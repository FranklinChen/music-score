
{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DeriveFoldable             #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE UndecidableInstances       #-}

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
-- Provides stretchable values.
--
-------------------------------------------------------------------------------------

module Music.Time.Stretchable (
        -- * Stretchable class
        Stretchable(..),
        compress,
        stretching,

        -- ** Utility
        NoStretch(..),
  ) where

import           Control.Arrow

import           Data.AffineSpace
import           Data.AffineSpace.Point
import           Data.Map               (Map)
import qualified Data.Map               as Map
import           Data.Semigroup
import           Data.Set               (Set)
import qualified Data.Set               as Set
import           Data.VectorSpace       hiding (Sum)

import           Music.Time.Time

-- |
-- Stretchable values.
--
class Stretchable a where

    -- |
    -- Stretch (augment) a value by the given factor.
    --
    stretch :: Duration -> a -> a
    stretch _ = id

instance Stretchable Time where
    stretch n = (n*.)

instance Stretchable Duration where
    stretch n = (n*^)

instance Stretchable (Time, a) where
    stretch n (t, a) = (n `stretch` t, a)

instance Stretchable (Duration, a) where
    stretch n (d, a) = (n `stretch` d, a)

instance Stretchable (Time, Duration, a) where
    stretch n (t, d, a) = (n `stretch` t, n `stretch` d, a)

instance Stretchable (Time -> a) where
    stretch n = (. relative origin (^/ n))

instance Stretchable (Duration -> a) where
    stretch n = (. (^/ n))

instance Stretchable a => Stretchable [a] where
    stretch n = fmap (stretch n)

instance Stretchable a => Stretchable (Map k a) where
    stretch n = fmap (stretch n)

instance Stretchable a => Stretchable (Product a) where
    stretch n (Product x) = Product (stretch n x)

instance Stretchable a => Stretchable (Sum a) where
    stretch n (Sum x) = Sum (stretch n x)


-- |
-- Compress (diminish) a score. Flipped version of 'stretch'.
--
compress :: Stretchable a => Duration -> a -> a
compress x = stretch (recip x)

-- | Apply a function under stretch.
--   See also 'sunder'.
stretching :: (Stretchable a, Stretchable b) => Duration -> (a -> b) -> a -> b
stretching t f = compress t . f . stretch t


newtype NoStretch a = NoStretch { getNoStretch :: a }
    deriving (Eq, Ord, Enum, Show, Semigroup, Monoid
        {-Delayable, HasOnset, HasOffset, HasDuration-})

instance Stretchable (NoStretch a) where
    stretch _ = id
