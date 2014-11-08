
{-# LANGUAGE CPP                        #-}
{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveFoldable             #-}
{-# LANGUAGE DeriveFunctor              #-}
{-# LANGUAGE DeriveTraversable          #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE NoMonomorphismRestriction  #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TupleSections              #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE UndecidableInstances       #-}


-------------------------------------------------------------------------------------
-- |
-- Copyright   : (c) Hans Hoglund 2012-2014
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides functions for manipulating pitch.
--
-------------------------------------------------------------------------------------


module Music.Score.Pitch (
        
        -- * Pitch type
        Pitch,
        SetPitch,
        Interval,
        
        -- * HasPitch classes
        HasPitch(..),
        HasPitches(..),
        fromPitch',

        -- ** Simple versions
        HasPitch',
        HasPitches',
        pitch',
        pitches',
        
        -- * Transposition
        up,
        down,
        above,
        below,
        octavesUp,
        octavesDown,
        octavesAbove,
        octavesBelow,
        fifthsUp,
        fifthsDown,
        fifthsAbove,
        fifthsBelow,
        _15va,
        _8va,
        _8vb,
        _15vb,

        -- * Inversion
        inv,
        invertPitches,

        -- * Folds
        highest,
        lowest,
        meanPitch,

        -- -- * Intervals
        -- augmentIntervals,

        -- TODO pitchIs, to write filter pitchIs ... etc
        -- TODO gliss etc

        PitchPair,
        AffinePair,
        Transposable,
        
  ) where

import           Control.Applicative
import           Control.Lens                  hiding (above, below, transform)
import           Control.Monad                 (MonadPlus (..), ap, join, liftM,
                                                mfilter)
import           Data.AffineSpace
import           Data.AffineSpace.Point
import           Data.Foldable                 (Foldable)
import           Data.Functor.Couple
import qualified Data.List                     as List
import           Data.Ratio
import           Data.Semigroup
import           Data.String
import           Data.Traversable              (Traversable)
import           Data.Typeable
import           Data.VectorSpace              hiding (Sum)

import           Music.Pitch.Literal
import           Music.Score.Harmonics
import           Music.Score.Part
import           Music.Score.Slide
import           Music.Score.Text
import           Music.Score.Ties
import           Music.Score.Phrases
import           Music.Time
import           Music.Time.Internal.Transform

-- |
-- This type fuction is used to access the pitch type for a given type.
--
type family Pitch (s :: *) :: *
--
-- @
-- 'Pitch' (c,a)             ~ 'Pitch' a
-- 'Pitch' [a]               ~ 'Pitch' a
-- 'Pitch' ('Event' a)          ~ 'Pitch' a
-- 'Pitch' ('Voice' a)         ~ 'Pitch' a
-- 'Pitch' ('Score' a)         ~ 'Pitch' a
-- @
--
-- For types representing pitch, it is generally 'Identity', i.e
--
-- @
-- Pitch Integer ~ Integer
-- Pitch Double ~ Double
-- @
--
-- and so on.
--
-- For containers, 'Pitch' provides a morphism:
--

-- |
-- This type fuction is used to update the pitch type for a given type.
-- The first argument is the new type.
--
type family SetPitch (b :: *) (s :: *) :: *
--
-- @
-- 'SetPitch' b (c,a)          ~ (c, 'SetPitch' b a)
-- 'SetPitch' b [a]            ~ ['SetPitch' b a]
-- 'SetPitch' g ('Event' a)       ~ Event ('SetPitch' g a)
-- 'SetPitch' g ('Voice' a)      ~ 'Voice' ('SetPitch' g a)
-- 'SetPitch' g ('Score' a)      ~ 'Score' ('SetPitch' g a)
-- @
--
-- For types representing pitch, it is generally 'Constant', i.e
--
-- @
-- SetPitch a Double ~ a
-- SetPitch a Integer ~ a
-- @
--
-- For containers, 'SetPitch' provides a morphism:
--

-- |
-- Class of types that provide a single pitch.
--
class HasPitches s t => HasPitch s t where

  -- | Access the pitch.
  --
  --   As this is a 'Traversal', you can use all combinators from the lens package,
  --   for example:
  --
  --   @
  --   'pitch' .~ c    :: ('HasPitch'' a, 'IsPitch' a)      => a -> a
  --   'pitch' +~ 2    :: ('HasPitch'' a, 'Num' ('Pitch' a))  => a -> a
  --   'pitch' %~ 'succ' :: ('HasPitch'' a, 'Enum' ('Pitch' a)) => a -> a
  --   'view' 'pitch'    :: 'HasPitches'' a                 => a -> 'Pitch' a
  --   'set'  'pitch'    :: 'HasPitches' a b                => 'Pitch' b -> a -> b
  --   'over' 'pitch'    :: 'HasPitches' a b                => ('Pitch' a -> 'Pitch' b) -> a -> b
  --   @
  --
  pitch :: Lens s t (Pitch s) (Pitch t)

-- |
-- Class of types that provide zero or more pitches.
--
class (Transformable (Pitch s),
       Transformable (Pitch t),
       SetPitch (Pitch t) s ~ t) => HasPitches s t where

  -- | Access all pitches.
  --
  --   As this is a 'Traversal', you can use all combinators from the lens package,
  --   for example:
  --
  --   @
  --   'toListOf' 'pitches'  :: 'HasPitches'' a                  => a -> ['Pitch' a]
  --   'allOf' 'pitches'     :: ('HasPitches'' a)                => ('Pitch' a -> 'Bool') -> a -> 'Bool'
  --   'maximumOf' 'pitches' :: ('HasPitches'' a, 'Ord' ('Pitch' a)) => a -> 'Maybe' ('Pitch' a)
  --   'set'  'pitches'      :: 'HasPitches' a b                 => 'Pitch' b -> a -> b
  --   'over' 'pitches'      :: 'HasPitches' a b                 => ('Pitch' a -> 'Pitch' b) -> a -> b
  --   @
  --
  pitches :: Traversal s t (Pitch s) (Pitch t)

type HasPitch' a = HasPitch a a

type HasPitches' a = HasPitches a a


-- | 
-- Access the pitch.
--
-- Same as 'pitch', but without polymorphic update.
--
pitch' :: (HasPitch s t, s ~ t) => Lens' s (Pitch s)
pitch' = pitch
{-# INLINE pitch' #-}

-- | 
-- Access all pitches.
-- 
-- Same as 'pitches', but without polymorphic update.
--
pitches' :: (HasPitches s t, s ~ t) => Traversal' s (Pitch s)
pitches' = pitches
{-# INLINE pitches' #-}

-- |
-- Inject a pitch into some larger type.
--
fromPitch' :: (HasPitches' a, IsPitch a) => Pitch a -> a
fromPitch' x = c & pitches' .~ x
{-# INLINE fromPitch' #-}
-- TODO swap name of this and Music.Pitch.Literal.fromPitch (or call that something else, i.e. fromPitchL)


#define PRIM_PITCH_INSTANCE(TYPE)       \
                                        \
type instance Pitch TYPE = TYPE;        \
type instance SetPitch a TYPE = a;      \
                                        \
instance (Transformable a, a ~ Pitch a) \
  => HasPitch TYPE a where {            \
  pitch = ($)              } ;          \
                                        \
instance (Transformable a, a ~ Pitch a) \
  => HasPitches TYPE a where {          \
  pitches = ($)              } ;        \


PRIM_PITCH_INSTANCE(())
PRIM_PITCH_INSTANCE(Bool)
PRIM_PITCH_INSTANCE(Ordering)
PRIM_PITCH_INSTANCE(Char)
PRIM_PITCH_INSTANCE(Int)
PRIM_PITCH_INSTANCE(Integer)
PRIM_PITCH_INSTANCE(Float)
PRIM_PITCH_INSTANCE(Double)


type instance Pitch (c,a)               = Pitch a
type instance SetPitch b (c,a)          = (c,SetPitch b a)
type instance Pitch [a]                 = Pitch a
type instance SetPitch b [a]            = [SetPitch b a]

type instance Pitch (Maybe a)           = Pitch a
type instance SetPitch b (Maybe a)      = Maybe (SetPitch b a)
type instance Pitch (Either c a)        = Pitch a
type instance SetPitch b (Either c a)   = Either c (SetPitch b a)

type instance Pitch (Event a)            = Pitch a
type instance SetPitch b (Event a)       = Event (SetPitch b a)
type instance Pitch (Placed a)         = Pitch a
type instance SetPitch b (Placed a)    = Placed (SetPitch b a)
type instance Pitch (Note a)       = Pitch a
type instance SetPitch b (Note a)  = Note (SetPitch b a)

type instance Pitch (Voice a)       = Pitch a
type instance SetPitch b (Voice a)  = Voice (SetPitch b a)
type instance Pitch (Track a)       = Pitch a
type instance SetPitch b (Track a)  = Track (SetPitch b a)
type instance Pitch (Score a)       = Pitch a
type instance SetPitch b (Score a)  = Score (SetPitch b a)

instance HasPitch a b => HasPitch (c, a) (c, b) where
  pitch = _2 . pitch
instance HasPitches a b => HasPitches (c, a) (c, b) where
  pitches = traverse . pitches

instance (HasPitches a b) => HasPitches (Event a) (Event b) where
  pitches = from event . whilstL pitches
instance (HasPitch a b) => HasPitch (Event a) (Event b) where
  pitch = from event . whilstL pitch

instance (HasPitches a b) => HasPitches (Placed a) (Placed b) where
  pitches = _Wrapped . whilstLT pitches
instance (HasPitch a b) => HasPitch (Placed a) (Placed b) where
  pitch = _Wrapped . whilstLT pitch

instance (HasPitches a b) => HasPitches (Note a) (Note b) where
  pitches = _Wrapped . whilstLD pitches
instance (HasPitch a b) => HasPitch (Note a) (Note b) where
  pitch = _Wrapped . whilstLD pitch

instance HasPitches a b => HasPitches (Maybe a) (Maybe b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Either c a) (Either c b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches [a] [b] where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Voice a) (Voice b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Track a) (Track b) where
  pitches = traverse . pitches

{-
type instance Pitch (Chord a)       = Pitch a
type instance SetPitch b (Chord a)  = Chord (SetPitch b a)
instance HasPitches a b => HasPitches (Chord a) (Chord b) where
  pitches = traverse . pitches
-}

instance (HasPitches a b) => HasPitches (Score a) (Score b) where
  pitches =
    _Wrapped . _2   -- into NScore
    . _Wrapped
    . traverse
    . from event    -- this needed?
    . whilstL pitches


type instance Pitch (Sum a) = Pitch a
type instance SetPitch b (Sum a) = Sum (SetPitch b a)

instance HasPitches a b => HasPitches (Sum a) (Sum b) where
  pitches = _Wrapped . pitches

type instance Pitch      (Behavior a) = Behavior a
type instance SetPitch b (Behavior a) = b

instance (Transformable a, Transformable b, b ~ Pitch b) => HasPitches (Behavior a) b where
  pitches = ($)
instance (Transformable a, Transformable b, b ~ Pitch b) => HasPitch (Behavior a) b where
  pitch = ($)


type instance Pitch (Couple c a)        = Pitch a
type instance SetPitch g (Couple c a)   = Couple c (SetPitch g a)

type instance Pitch (TextT a)           = Pitch a
type instance SetPitch g (TextT a)      = TextT (SetPitch g a)
type instance Pitch (HarmonicT a)       = Pitch a
type instance SetPitch g (HarmonicT a)  = HarmonicT (SetPitch g a)
type instance Pitch (TieT a)            = Pitch a
type instance SetPitch g (TieT a)       = TieT (SetPitch g a)
type instance Pitch (SlideT a)          = Pitch a
type instance SetPitch g (SlideT a)     = SlideT (SetPitch g a)

instance (HasPitches a b) => HasPitches (Couple c a) (Couple c b) where
  pitches = _Wrapped . pitches
instance (HasPitch a b) => HasPitch (Couple c a) (Couple c b) where
  pitch = _Wrapped . pitch
  
instance (HasPitches a b) => HasPitches (TextT a) (TextT b) where
  pitches = _Wrapped . pitches
instance (HasPitch a b) => HasPitch (TextT a) (TextT b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (HarmonicT a) (HarmonicT b) where
  pitches = _Wrapped . pitches
instance (HasPitch a b) => HasPitch (HarmonicT a) (HarmonicT b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (TieT a) (TieT b) where
  pitches = _Wrapped . pitches
instance (HasPitch a b) => HasPitch (TieT a) (TieT b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (SlideT a) (SlideT b) where
  pitches = _Wrapped . pitches
instance (HasPitch a b) => HasPitch (SlideT a) (SlideT b) where
  pitch = _Wrapped . pitch


-- |
-- Associated interval type.
--
type Interval a = Diff (Pitch a)

type PitchPair  v w = (Num (Scalar v), IsInterval v, IsPitch w)
type AffinePair v w = (VectorSpace v, AffineSpace w)

-- |
-- Class of types that can be transposed, inverted and so on.
--
type Transposable a = (
  HasPitches' a,
  AffinePair (Interval a) (Pitch a),
  PitchPair (Interval a) (Pitch a)
  )

-- |
-- Transpose pitch upwards.
--
-- Not to be confused with matrix transposition.
--
-- >>> up m3 c
-- eb
--
-- >>> up _P5 [c,d,e :: Pitch]
-- [g,a,b]
--
-- >>> up _P5 [440 :: Hertz, 442, 810]
-- [g,a,b]
--
up :: Transposable a => Interval a -> a -> a
up v = pitches %~ (.+^ v)
{-# INLINE up #-}

-- |
-- Transpose pitch downwards.
--
-- Not to be confused with matrix transposition.
--
-- >>> down m3 c
-- a
--
-- >>> down _P5 [c,d,e]
-- [f_,g_,a_]
--
down :: Transposable a => Interval a -> a -> a
down v = pitches %~ (.-^ v)
{-# INLINE down #-}

-- |
-- Add the given interval above.
--
-- >>> above _P8 [c]
-- [c,c']
--
above :: (Semigroup a, Transposable a) => Interval a -> a -> a
above v x = x <> up v x
{-# INLINE above #-}

-- |
-- Add the given interval below.
--
-- >>> below _P8 [c]
-- [c,c_]
--
below :: (Semigroup a, Transposable a) => Interval a -> a -> a
below v x = x <> down v x
{-# INLINE below #-}

inv :: Transposable a => Pitch a -> a -> a
inv = invertPitches
{-# DEPRECATED inv "Use 'invertPitches'" #-}

-- |
-- Invert pitches.
--
invertPitches :: Transposable a => Pitch a -> a -> a
invertPitches p = pitches %~ reflectThrough p

-- |
-- Transpose up by the given number of octaves.
--
-- >>> octavesUp 2 c
-- c''
--
-- >>> octavesUp 1 [c,d,e]
-- [c',d',e']
--
-- >>> octavesUp (-1) [c,d,e]
-- [c_,d_,e_]
--
octavesUp :: Transposable a => Scalar (Interval a) -> a -> a
octavesUp n = up (_P8^*n)
{-# INLINE octavesUp #-}

-- |
-- Transpose down by the given number of octaves.
--
-- >>> octavesDown 2 c
-- c__
--
-- >>> octavesDown 1 [c,d,e]
-- [c_,d_,e_]
--
-- >>> octavesDown (-1) [c,d,e]
-- [c',d',e']
--
octavesDown :: Transposable a => Scalar (Interval a) -> a -> a
octavesDown n = down (_P8^*n)
{-# INLINE octavesDown #-}

-- |
-- Add the given octave above.
--
octavesAbove :: (Semigroup a, Transposable a) => Scalar (Interval a) -> a -> a
octavesAbove n = above (_P8^*n)
{-# INLINE octavesAbove #-}

-- |
-- Add the given octave below.
--
octavesBelow :: (Semigroup a, Transposable a) => Scalar (Interval a) -> a -> a
octavesBelow n = below (_P8^*n)
{-# INLINE octavesBelow #-}

-- |
-- Transpose up by the given number of fifths.
--
fifthsUp :: Transposable a => Scalar (Interval a) -> a -> a
fifthsUp n = up (_P8^*n)
{-# INLINE fifthsUp #-}

-- |
-- Transpose down by the given number of fifths.
--
fifthsDown :: Transposable a => Scalar (Interval a) -> a -> a
fifthsDown n = down (_P8^*n)
{-# INLINE fifthsDown #-}

-- |
-- Add the given octave above.
--
fifthsAbove :: (Semigroup a, Transposable a) => Scalar (Interval a) -> a -> a
fifthsAbove n = above (_P8^*n)
{-# INLINE fifthsAbove #-}

-- |
-- Add the given octave below.
--
fifthsBelow :: (Semigroup a, Transposable a) => Scalar (Interval a) -> a -> a
fifthsBelow n = below (_P8^*n)
{-# INLINE fifthsBelow #-}

-- | Shorthand for @'octavesUp' 2@.
_15va :: Transposable a => a -> a
_15va = octavesUp 2
{-# INLINE _15va #-}

-- | Shorthand for @'octavesUp' 1@.
_8va :: Transposable a => a -> a
_8va  = octavesUp 1
{-# INLINE _8va #-}

-- | Shorthand for @'octavesDown' 1@.
_8vb :: Transposable a => a -> a
_8vb  = octavesDown 1
{-# INLINE _8vb #-}

-- | Shorthand for @'octavesDown' 2@.
_15vb :: Transposable a => a -> a
_15vb = octavesDown 2
{-# INLINE _15vb #-}


-- |
-- Return the highest pitch in the given music.
--
highest :: (HasPitches' a, Ord (Pitch a)) => a -> Maybe (Pitch a)
highest = maximumOf pitches'

-- |
-- Return the lowest pitch in the given music.
--
lowest :: (HasPitches' a, Ord (Pitch a)) => a -> Maybe (Pitch a)
lowest = minimumOf pitches'

-- |
-- Return the mean pitch in the given music.
--
meanPitch :: (HasPitches' a, Fractional (Pitch a)) => a -> Pitch a
meanPitch = mean . toListOf pitches'
  where
    mean x = fst $ foldl (\(m, n) x -> (m+(x-m)/(n+1),n+1)) (0,0) x


augmentIntervals :: (HasPhrases' s a, Transposable a) => Interval a -> s -> s
augmentIntervals x = over phrases (augmentIntervals' x)

augmentIntervals' :: Transposable a => Interval a -> Voice a -> Voice a
augmentIntervals' = error "Not implemented: augmentIntervals"
-- TODO generalize to any type where we can traverse phrases of something that has pitch


-- TODO augment/diminish intervals (requires phrase traversal)
-- TODO rotatePitch (requires phrase traversal)
-- TODO invert diatonically

