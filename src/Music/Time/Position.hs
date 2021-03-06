
{-# LANGUAGE CPP                        #-}

-- |
-- Provides a way to query a value for its 'position'.
module Music.Time.Position (
      module Music.Time.Duration,

      -- * The HasPosition class
      HasPosition(..),

      -- * Position and Era
      position,
      era,

      -- ** Specific positions
      onset,
      midpoint,
      offset,
      preOnset,
      postOffset,
      postOnset,

      -- * Moving
      startAt,
      stopAt,
      placeAt,

      -- * Transforming relative a position
      stretchRelative,
      stretchRelativeOnset,
      stretchRelativeMidpoint,
      stretchRelativeOffset,

      delayRelative,
      delayRelativeOnset,
      delayRelativeMidpoint,
      delayRelativeOffset,

      transformRelative,
      transformRelativeOnset,
      transformRelativeMidpoint,
      transformRelativeOffset,
  ) where


import           Control.Lens             hiding (Indexable, Level, above,
                                           below, index, inside, parts,
                                           reversed, transform, (<|), (|>))
import           Data.AffineSpace
import           Data.AffineSpace.Point
import           Data.Map                 (Map)
import qualified Data.Map                 as Map
import           Data.Semigroup
import           Data.Set                 (Set)
import qualified Data.Set                 as Set
import           Data.VectorSpace         hiding (Sum)


import           Music.Time.Duration
import           Music.Time.Internal.Util

-- |
-- Class of values that have a position in time.
--
-- Many values such as notes, envelopes etc can in fact have many positions such as onset,
-- attack point, offset, decay point time etc. Rather than having separate methods for a
-- fixed set of cases, this class provides an interpolation from a /local/ position to
-- a /global/ position. While the local position goes from zero to one, the global position
-- goes from the 'onset' to the 'offset' of the value.
--
-- Instances should satisfy:
--
-- @
-- x ^. 'duration'   = x ^. 'era' . 'duration'
-- x ^. 'position' n = x ^. 'era' . 'position' n
-- ('transform' s x) ^. 'era' = 'transform' s (x ^. 'era')
-- @
--
class HasDuration a => HasPosition a where

  -- | Map a local time in value to global time.
  _position :: a -> Duration -> Time
  _position x = alerp a b where (a, b) = (_era x)^.onsetAndOffset

  -- | Return the conventional bounds of a value (local time zero and one).
  _era :: HasPosition a => a -> Span
  _era x = x `_position` 0 <-> x `_position` 1

  {-# MINIMAL (_position | _era) #-}

instance HasPosition Span where
  _era = id

#ifndef GHCI
instance (HasPosition a, Transformable a) => HasDuration [a] where
  _duration x = _offset x .-. _onset x

instance (HasPosition a, Transformable a) => HasPosition [a] where
  _era x = (f x, g x)^.from onsetAndOffset
    where
      f  = foldr min 0 . fmap _onset
      g = foldr max 0 . fmap _offset
#endif
#line 123

-- |
-- Position of the given value.
--
position :: (HasPosition a, Transformable a) => Duration -> Lens' a Time
position d = lens (`_position` d) (flip $ placeAt d)
{-# INLINE position #-}

-- |
-- Onset of the given value.
--
onset :: (HasPosition a, Transformable a) => Lens' a Time
onset = position 0
{-# INLINE onset #-}

-- |
-- Onset of the given value.
--
offset :: (HasPosition a, Transformable a) => Lens' a Time
offset = position 1
{-# INLINE offset #-}

-- |
-- Pre-onset of the given value, or the value right before the attack phase.
--
preOnset :: (HasPosition a, Transformable a) => Lens' a Time
preOnset = position (-0.5)
{-# INLINE preOnset #-}

-- |
-- Midpoint of the given value, or the value between the decay and sustain phases.
--
midpoint :: (HasPosition a, Transformable a) => Lens' a Time
midpoint = position 0.5
{-# INLINE midpoint #-}

postOnset :: (HasPosition a, Transformable a) => Lens' a Time
postOnset = position 0.5
{-# DEPRECATED postOnset "Use midpoint" #-}

-- |
-- Post-offset of the given value, or the value right after the release phase.
--
postOffset :: (HasPosition a, Transformable a) => Lens' a Time
postOffset = position 1.5
{-# INLINE postOffset #-}



-- |
-- Move a value forward in time.
--
startAt :: (Transformable a, HasPosition a) => Time -> a -> a
startAt t x = (t .-. x^.onset) `delay` x

-- |
-- Move a value forward in time.
--
stopAt  :: (Transformable a, HasPosition a) => Time -> a -> a
stopAt t x = (t .-. x^.offset) `delay` x

-- |
-- Align a value to a given position.
--
-- @placeAt p t@ places the given thing so that its position p is at time t
--
-- @
-- 'placeAt' 0 = 'startAt'
-- 'placeAt' 1 = 'stopAt'
-- @
--
placeAt :: (Transformable a, HasPosition a) => Duration -> Time -> a -> a
placeAt p t x = (t .-. x `_position` p) `delay` x

_onset, _offset :: (HasPosition a, Transformable a) => a -> Time
_onset     = (`_position` 0)
_offset    = (`_position` 1.0)

-- |
-- Place a value over the given span.
--
-- @placeAt s t@ places the given thing so that @x^.place = s@
--
_setEra :: (HasPosition a, Transformable a) => Span -> a -> a
_setEra s x = transform (s ^-^ view era x) x

-- |
-- A lens to the position
--
era :: (HasPosition a, Transformable a) => Lens' a Span
era = lens _era (flip _setEra)
{-# INLINE era #-}

stretchRelative :: (HasPosition a, Transformable a) => Duration -> Duration -> a -> a
stretchRelative p n x = over (transformed $ undelaying (realToFrac $ x^.position p)) (stretch n) x

stretchRelativeOnset :: (HasPosition a, Transformable a) => Duration -> a -> a
stretchRelativeOnset = stretchRelative 0

stretchRelativeMidpoint :: (HasPosition a, Transformable a) => Duration -> a -> a
stretchRelativeMidpoint = stretchRelative 0.5

stretchRelativeOffset :: (HasPosition a, Transformable a) => Duration -> a -> a
stretchRelativeOffset = stretchRelative 1

delayRelative :: (HasPosition a, Transformable a) => Duration -> Duration -> a -> a
delayRelative p n x = over (transformed $ undelaying (realToFrac $ x^.position p)) (delay n) x

delayRelativeOnset :: (HasPosition a, Transformable a) => Duration -> a -> a
delayRelativeOnset = delayRelative 0

delayRelativeMidpoint :: (HasPosition a, Transformable a) => Duration -> a -> a
delayRelativeMidpoint = delayRelative 0.5

delayRelativeOffset :: (HasPosition a, Transformable a) => Duration -> a -> a
delayRelativeOffset = delayRelative 1

transformRelative :: (HasPosition a, Transformable a) => Duration -> Span -> a -> a
transformRelative p n x = over (transformed $ undelaying (realToFrac $ x^.position p)) (transform n) x

transformRelativeOnset :: (HasPosition a, Transformable a) => Span -> a -> a
transformRelativeOnset = transformRelative 0

transformRelativeMidpoint :: (HasPosition a, Transformable a) => Span -> a -> a
transformRelativeMidpoint = transformRelative 0.5

transformRelativeOffset :: (HasPosition a, Transformable a) => Span -> a -> a
transformRelativeOffset = transformRelative 1


