data MyColors = Orange | Red | Blue | Green | Silver
 deriving (Show, Eq)

-- | Custom Ord instance that sorts colors alphabetically by their string
-- representation (via 'show'), rather than by declaration order. For example,
-- Blue < Green < Orange < Red < Silver. With @deriving Ord@, the order would
-- follow the data constructor order: Orange < Red < Blue < Green < Silver.
instance Ord MyColors where
  compare c1 c2 = compare (show c1) (show c2)
