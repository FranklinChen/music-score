
-- |
-- Utilities for working with time values.
--
-- TODO Move. Perhaps these could be added to vector-space-point?
--
module Music.Time.Relative where

import Data.Semigroup
import Data.VectorSpace
import Data.AffineSpace
import Data.AffineSpace.Point

-- | 
-- Apply a transformation around the given point.
-- 
relative :: AffineSpace p => p -> (Diff p -> Diff p) -> p -> p
relative p f = (p .+^) . f . (.-. p)

-- |
-- Mirror a point around 'origin'.
--
mirror :: AdditiveGroup v => Point v -> Point v
mirror = relative origin negateV
