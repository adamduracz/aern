module Main where

import Numeric.AERN.RmToRn.Basis.Polynomial.IntPoly
import Numeric.AERN.RmToRn.New
import Numeric.AERN.RmToRn.Domain

import Numeric.AERN.RealArithmetic.Basis.MPFR
import qualified Numeric.AERN.MPFRBasis.Interval as MI

import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsDefaultEffort

import qualified Numeric.AERN.RefinementOrder as RefOrd

import Numeric.AERN.Basics.ShowInternals

import Numeric.AERN.Misc.Debug

import System.IO

import qualified Data.Map as Map
import qualified Data.List as List

type Poly = IntPoly String MI.MI

shouldPrintPrecision = False
--shouldPrintPrecision = True

gravity :: Rational
gravity = 10

initHeight :: Rational
initHeight = 10

-- TODO:
-- define a new truthvalue datatype ThereExistsReal with operations: 
--  (?<?), (?<=?), (?==?) :: Poly -> Poly -> ThereExistsReal
--  (?&&?), (?||?) :: ThereExistsReal -> ThereExistsReal -> ThereExistsReal
--  run :: ThereExistsReal -> (Poly -> (MI,MI) -> (MI,MI)) -> (MI,MI) -> Maybe Bool
-- that semi-decides the encoded condition as an existential over a given time domain
-- making use of the intermediate theorem to semi-decide equalities
-- this will allow one to change the <=? to ?==? in the bounceCond
-- and get rid of bounceCondSomewhereOnTimeInterval

bounceCond (y, yDer) =
    (y MI.<=? 0) &&? (yDer MI.<? 0)
    
bounceCondSomewhereOnTimeInterval evalPolyAt dom (yPoly, yDerPoly)
    | condOnDom /= Nothing = condOnDom
    | condOnDomL == Just True || condOnDomR == Just True = condOnDomR
    | otherwise = Nothing 
    where
    (domL, domR) = RefOrd.getEndpointsOutWithDefaultEffort dom
    condOnDom = bounceCondOn dom
    condOnDomL = bounceCondOn domL
    condOnDomR = bounceCondOn domR
    bounceCondOn d 
        = bounceCond (evalPolyAt d yPoly, evalPolyAt d yDerPoly)
    
bounceAction (y, yDer) = 
    (c0, (-0.5 :: Rational) |<*> yDer)
    where
    c0 = newConstFn cfg undefined 0
    cfg = getSizeLimits y 

data Params =
    Params
    {
        paramStepSize :: Int, -- 2^{-s} step size
        paramMaxEvents :: Int, -- how many events within one event time segment to consider before giving up 
        paramLocEpsilon :: Int, -- 2^{-n} precision of bounce location
        paramPrecision :: Precision -- floating point precision
--        paramDegree :: Int, -- maximal polynomial degree
--        paramTermSize :: Int, -- maximal polynomial term size
--        paramRangeTolerance :: Int 
            -- 2^{-r} how hard to try to estimate ranges of polynomials 
            --        by splitting - currently unused
    }
    deriving (Show)
-- Zeno point is at 3*(sqrt 2) = 4.242640...
--initParams = Params 0 10   90   100 --  21 bounces, then until 4.242703 in 0.9s
initParams = Params 0 10  100  100 --  23 bounces, then until 4.242656 in 1s
--initParams = Params 0 10  200  200 --  46 bounces, then until 4.242675 in 4s
--initParams = Params 0 10  300  300 --  68 bounces, then until 4.242658 in 9s
--initParams = Params 0 10  400 400 --  91 bounces, then until 4.242675 in 16s
--initParams = Params 0 10  600 1000 -- 135 bounces, then until 4.242649 in <35s
--initParams = Params 0 10  100 1000 -- 23 bounces, then until 4.242649 in <35s
--initParams = Params 0 10 1600 2000 -- 329 bounces, then until 4.242658 in 4min
--initParams = Params 0 10 4000 6000 -- 819 bounces in around 30min 

--initParams = Params 0 10 1000 1000 -- cannot reliably analyse the event the first bounce - need to reduce loc epsilon 

main =
    do
    hSetBuffering stdout NoBuffering
    print initParams 
    putStrLn $ "initial state: " ++ show (head steps)
    mapM_ (printStep initParams) $ tail steps 
    print initParams 
    where
    steps = simulate initParams

--increaseParams (Params stp eps p dg rtol) =
--    [
--     Params stp eps p dgNew rtol, 
--     Params stp epsNew pNew dg rtol, 
--     Params stp epsNew pNew dgNew rtol
--    ]
--    where
--    pNew = p + 2000
--    dgNew = dg + 200
--    epsNew = eps + 2000
--
--paramSearch prevBest nextParamsOptions@(params : rest)
--    | prevBest > 36000 = []
--    | otherwise =
--        (params, currentScoreSeq, currentScore) : 
--            (case (rest, currentScore > prevBest + 1) of
--                ([], _) -> paramSearch currentScore $ increaseParams params
--                (_, True) -> paramSearch currentScore $ increaseParams params
--                _ -> paramSearch prevBest rest
--            )
--         where
--         currentScoreSeq =
--            drop100ifAny 0 $ zip [0..] steps
--         drop100ifAny n [] = []
--         drop100ifAny n list 
--            = 
--            (n `div` stepsInOne) 
--            : (drop100ifAny (n + 100) $ drop 100 list)
--         currentScore =
--            (length steps) `div` stepsInOne
--         steps = simulate params
--         stepsInOne = 2 ^ (paramStepSize params)

simulate params =
    waitTillPrecBelow (10^^(-4)) $ -- stop when diverging
        iterate (makeStep params stepSize locEpsilon) 
            ((tInit, 0, y0Init, yDer0Init),[]) -- initial values
    where
    tInit = i2mi 0
    y0Init = i2mi initHeight
    yDer0Init = i2mi 0
    waitTillPrecBelow eps (this@(((_,_,yNmOne,_),_)):rest)
        | precGood = this : (waitTillPrecBelow eps rest)
        | otherwise = [this]
        where
        precGood = 
            case MI.width yNmOne MI.<? eps of
                Just True -> True
                _ -> False
    locEpsilon =
        (i2mi 1) MI.</> (i2mi $ 2^(paramLocEpsilon params))
    stepSize
        | stp >= 0 =(i2mi 1) MI.</> (i2mi $ 2^stp)
        | otherwise = i2mi $ 2^(- stp)
        where
        stp = paramStepSize params
    i2mi :: Rational -> MI.MI
    i2mi n =
        ArithInOut.convertOutEff (paramPrecision params) n
    
printStep params ((t,prevEvents,y,yDer), eventEnclsAtHE) =
    do
    putStrLn $ replicate 120 '*'
    putStrLn $ "solving for t = " ++ show t ++ "(events so far = " ++ show prevEvents ++ ")" ++ ":"
    putStrLn $ " beyond Zeno: " ++ (show $ t MI.>? zenoPt)
    putStrLn $ " enclosures assuming exactly n events:"
    mapM_ putStrLn $ map printEventEncl $ zip [0..] eventEnclsAtHE
    putStrLn $ " result: "
    putStrLn $ "  y(t) = " ++ showMI y
    putStrLn $ "   y'(t) = " ++ showMI yDer
    putStrLn $ " width of y = " ++ showMI (MI.width y)
    where
    showMI = showInternals (30,shouldPrintPrecision)
    zenoPt = (i2mi 3) <*> (MI.sqrtOut (i2mi 2))
    prec = paramPrecision params
    i2mi :: Rational -> MI.MI
    i2mi n =
        ArithInOut.convertOutEff prec n

printEventEncl (n, ((yEv,yDerEv), maybeBouncedAfter)) =
    "\n  event count " ++ show n ++ ":"
    ++ "\n    y(t) = " ++ (showMI yEv)
    ++ "\n      y'(t) = " ++ (showMI yDerEv)
    ++ "\n        further bounce possible = " ++ show maybeBouncedAfter
    where
    showMI = showInternals (30,shouldPrintPrecision)
    
makeStep params h locEpsilon ((t, eventCount, y0, yDer0),_) =
--    unsafePrint
--    (
--        "makeStep:"
--        ++ "\n h = " ++ showMI h
--        ++ "\n t = " ++ showMI t
--        ++ "\n y0 = " ++ showMI y0
--        ++ "\n yDer0 = " ++ showMI yDer0
--        ++ "\n yh = " ++ showMI yh
--        ++ "\n yhDer = " ++ showMI yhDer
--    ) $
    case fst $ locateFirstBounce params (yWidth <+> locEpsilon) (0 MI.</\> h) (yPolyNoEvent, yDerPolyNoEvent) of
        Nothing -> -- certainly not bounced, yPoly and yDerPoly enclose solution over (0,h)
            ((t <+> h, eventCount, yh, yhDer), [])
            where
            (yh, yhDer) = 
                (evalStepPolyAt h yPolyNoEvent, 
                 evalStepPolyAt h yDerPolyNoEvent)
        -- TODO: merge the following two cases and simplify locateFirstBounce
        (Just bounceLoc) -> -- maybe bounced, if it did, it was here for the first time
            simulateEventsAux bounceLoc
    where
    yWidth = max y0Width yDer0Width
    y0Width = MI.width y0
    yDer0Width = MI.width yDer0
    simulateEventsAux bounceLoc@(bounceLocL, bounceLocR) 
        = simulateEvents params t eventCount (yBounceL, yDerBounceL) bounceLoc
        where
        -- shift attention to the interval bounceLoc, which is our event analysis time segment
        (yBounceL, yDerBounceL) = -- values at the start of event analysis time segment
            (evalStepPolyAt bounceLocL yPolyNoEvent, 
             evalStepPolyAt bounceLocL yDerPolyNoEvent)
    evalStepPolyAt dom = evalPolyOnInterval (effMI prec) [dom, y0, yDer0]
    
--    showMI = showInternals (20, shouldPrintPrecision)
    -- solve the ODE assuming there are no events:
    (yPolyNoEvent, yDerPolyNoEvent) = solveUncValODE params c0 (y0Poly, yDer0Poly)
        where
        -- construct polynomials that encode the initial values:
        [y0Poly, yDer0Poly] = map (newProjection cfg dombox) ["y0","yDer0"]
        cfg = 
            IntPolyCfg 
                {
                    ipolycfg_vars = vars,
                    ipolycfg_domsLZ = domsLZ,
                    ipolycfg_domsLE = domsLE,
                    ipolycfg_sample_cf = h,
                    ipolycfg_maxdeg = 2,
                    ipolycfg_maxsize = 0 -- not used at the moment
                }
        dombox = Map.fromList $ zip vars doms
        vars = ["u","y0","yDer0"]
        domsLZ = [(0 MI.</\> h), y0 <-> y0LE, yDer0 <-> yDer0LE]
        domsLE = [0, y0LE, yDer0LE]
        doms = [(0 MI.</\> h), y0, yDer0]
        (y0LE, _) = RefOrd.getEndpointsOutWithDefaultEffort y0
        (yDer0LE, _) = RefOrd.getEndpointsOutWithDefaultEffort yDer0
    
    c0 = i2mi 0
    c1 = i2mi 1 
    i2mi :: Integer -> MI.MI
    i2mi n = ArithInOut.convertOutEff prec n
    prec = paramPrecision params
    
simulateEvents params t eventCount (yBounceL, yDerBounceL) bounceLoc@(bounceLocL, bounceLocR)
    =
    ((leftBound $ t <+> bounceLocR, 
      eventCount <+> eventsHere, 
      yAtHE, yDerAtHE), 
     hopefullyFiniteEventEnclosuresAtHE)
    where
    he = bounceLocR <-> bounceLocL -- event analysis segment size
    evalBounceStepPolyAt dom -- evaluate polynomials with u=0 representing t=bounceLocL
        = evalPolyOnInterval (effMI prec) [dom, yBounceL, yDerBounceL]

    -- enclosures of the solution at the end of event analysis time segment:
    (yAtHE, yDerAtHE)
        | null possibleLastEventsEnclosuresAtHE =
            error $ "simulateEvents: possibleLastEventsEnclosuresAtHE is empty" 
        |otherwise = foldl1 mergePairs possibleLastEventsEnclosuresAtHE 
        where
        mergePairs (y1, yDer1) (y2, yDer2) = (y1 MI.</\> y2, yDer1 MI.</\> yDer2)
        possibleLastEventsEnclosuresAtHE 
            = map fst $ filter (couldBeLast . snd) $ hopefullyFiniteEventEnclosuresAtHE
            where
            couldBeLast maybeBouncedAfter = maybeBouncedAfter /= Just True
    eventsHere 
        | maybeInfinite = eventsAnalysed MI.</\> (1/0)
        | otherwise = eventsAnalysed
        where
        eventsAnalysed
            | null hopefullyFiniteEventEnclosuresAtHE =
                error $ "simulateEvents: hopefullyFiniteEventEnclosuresAtHE is empty" 
            |otherwise =             
                foldl1 (MI.</\>) $ map (fromInteger . fst) $ 
                    filter couldBeLast $ zip [0..] hopefullyFiniteEventEnclosuresAtHE
        couldBeLast (n, (_,maybeBouncedAfter)) = maybeBouncedAfter /= Just True
    
    (hopefullyFiniteEventEnclosuresAtHE, maybeInfinite) = 
--        unsafePrint
--        (
--            "simulateEvents: "
--            ++ "\n take 2 eventEnclosuresAtHE = " ++ (show $ take 2 $ eventEnclosuresAtHE)
--            ++ "\n |hopefullyFiniteEventEnclosuresAtHE| = " ++ (show $ length $ fst result)
--        ) $
        result
        where
        result = detectEnd maxEvents Nothing [] eventEnclosuresAtHE
        maxEvents = paramMaxEvents params
        -- detect last event or whether it suffices to consider 
        -- only a finite number of infinitely many potential events:
        detectEnd 0 _ prevEvents _ = 
            error $ 
                "forced to consider more than maxEvents ( = " ++ show maxEvents ++ ") events"
                ++ "\n event enclosures:" 
                ++ (unlines $ map printEventEncl $ zip [0..] $ reverse prevEvents)
        detectEnd n _ prevEvents (event1@(_,Just False):_) 
            = (reverse $ event1 : prevEvents, False) -- definitely last event
        detectEnd n (Just (yPrev, yDerPrev)) prevEvents (event1@((y1, yDer1),_):_)
            | ((yPrev MI.|<=? y1) == Just True) && -- yPrev approximates y1 (ie y1 is included in yPrev)
              ((yDerPrev MI.|<=? yDer1) == Just True) 
                =  (reverse $ ((y1, yDer1),Nothing) : prevEvents, True) 
                -- erase knowledge of next event 
                -- to ensure this enclosure is counted as a potential last event enclosure
        detectEnd n maybePrevEncls prevEvents (event@((y1,yDer1),_) : rest) = 
            detectEnd (n - 1) prevAndCurrentEncls (event : prevEvents) rest
            where
            prevAndCurrentEncls =
                case maybePrevEncls of
                    Nothing -> Just (y1, yDer1)
                    Just (y, yDer) -> Just (y MI.</\> y1, yDer MI.</\> yDer1) 
        detectEnd n _ prevEvents empty = (reverse prevEvents, False)

    eventEnclosuresAtHE = map evalAtHE eventEnclosures

    -- enclosures of the solution from i-th event until (i+1)-th event:
    eventEnclosures = iterate getNextEvent ((yPoly0, yDerPoly0), maybeBouncedAfter0)
        where
        maybeBouncedAfter0 =
            bounceCondSomewhereOnTimeInterval 
                evalBounceStepPolyAt (0 MI.</\> he) (yPoly0, yDerPoly0)

    -- (re-)obtain enclosures of solutions that assume no events, but with a different initial time point:  
    (yPoly0, yDerPoly0) = solveUncValODE params c0 (yBounceLPoly, yDerBounceLPoly)
        where
        -- construct polynomials that encode the initial values:
        [yBounceLPoly, yDerBounceLPoly] = map (newProjection cfg dombox) ["y0","yDer0"]
        cfg = 
            IntPolyCfg 
                {
                    ipolycfg_vars = vars,
                    ipolycfg_domsLZ = domsLZ,
                    ipolycfg_domsLE = domsLE,
                    ipolycfg_sample_cf = he,
                    ipolycfg_maxdeg = 2,
                    ipolycfg_maxsize = 1000
                }
        dombox = Map.fromList $ zip vars doms
        vars = ["u","y0","yDer0"]
        doms = [(0 MI.</\> he), yBounceL, yDerBounceL]
        domsLZ = [(0 MI.</\> he), yBounceL <-> yBounceLLE , yDerBounceL <-> yDerBounceLLE]
        domsLE = [0, yBounceLLE, yDerBounceLLE]
        (yBounceLLE, _) = RefOrd.getEndpointsOutWithDefaultEffort yBounceL 
        (yDerBounceLLE, _) = RefOrd.getEndpointsOutWithDefaultEffort yDerBounceL 

    getNextEvent event@((yPoly, yDerPoly), _maybeBouncedAfter) =
        ((yPolyNext, yDerPolyNext), maybeBouncedAfterNext)
        where
        maybeBouncedAfterNext =
            bounceCondSomewhereOnTimeInterval 
                evalBounceStepPolyAt (0 MI.</\> he) (yPolyNext, yDerPolyNext)
        (yPolyNext, yDerPolyNext) = solveUncTimeValODE params c0 he (yBounced, yDerBounced) 
        (yBounced, yDerBounced) = bounceAction (yPoly, yDerPoly) 

    evalAtHE ((yiPoly, yDeriPoly), maybeLasti) = ((yiAtHE, yDeriAtHE), maybeLasti)
        where 
        yiAtHE = evalBounceStepPolyAt he yiPoly
        yDeriAtHE = evalBounceStepPolyAt he yDeriPoly 

    c0 = i2mi 0
    c1 = i2mi 1 
    i2mi :: Integer -> MI.MI
    i2mi n = ArithInOut.convertOutEff prec n
    prec = paramPrecision params

locateFirstBounce ::
    Params ->
    MI.MI ->
    MI.MI ->
--    (MI.MI -> MI.MI -> MI.MI) ->
    (Poly, Poly) ->
    (Maybe -- Nothing = the guard is false everywhere in the domain  
    (MI.MI, MI.MI), -- the guard false outside this interval - inside it, we do not know
     Bool) -- is there certainly an event?
locateFirstBounce params locEpsilon dom (y0Poly, yDer0Poly)
    = aux 0 False dom
    where
    aux n prevDetectedEvent dom =
--        result `seq`
--        unsafePrintReturn
--        (
--            "locateFirstBounce:" ++ (replicate n ' ') ++ "dom: " ++ show dom ++ " result: "
--        )
        (maybeloc, prevDetectedEvent || eventIsCertain)
        where
        result@(maybeloc, eventIsCertain) =
            case bounceCondSomewhereOnTimeInterval evalPolyAt dom (y0Poly, yDer0Poly) of
                Just True
                    | tooSmall -> (Just (domL, domR), True)
                    | otherwise -> split True
                Just False 
                    -> (Nothing, False) -- false on dom
                _ 
                    | tooSmall -> (Just (domL, domR), False) -- cannot say anything about the guard on dom
                    | otherwise -> split prevDetectedEvent
            where
            (domL, domR) = RefOrd.getEndpointsOutWithDefaultEffort dom
        tooSmall 
            = ((MI.width dom) MI.<=? locEpsilon) == Just True
        split prevDetectedEvent
            = 
            case (aux (n+1) False dom1) of -- try left half first
                res@(_, True) -> res -- it is here!
                (Nothing, _) -> -- not here..
                    aux (n+1) prevDetectedEvent dom2 -- try next door
                res@(Just b@(bL,_), _) -> -- cannot rule it out in the left half
                    case (aux (n+1) False dom2) of
                        (Nothing, _) -> res -- nothing in the right half, left half rules
                        (Just (_,bR), isCertain) -- it could be here, but possibly not the firt occurrence
                            -> (Just (bL, bR), isCertain)
        (dom1, dom2) = defaultDomSplit sampleP dom
        sampleP = y0Poly

        evalPolyAt dom = evalPolyOnInterval (effMI prec) [dom,y0,yDer0]
        [_,y0, yDer0] =
            zipWith (<+>)
                (ipolycfg_domsLZ $ getSizeLimits $ y0Poly)
                (ipolycfg_domsLE $ getSizeLimits $ y0Poly)

    c0 = i2mi 0
    i2mi :: Integer -> MI.MI
    i2mi n = ArithInOut.convertOutEff prec n
    prec = paramPrecision params


solveUncValODE ::
    Params ->
--    MI {-^ starting time -} -> -- autonomous system, always 0 
    MI.MI {-^ zero with correct precision -} ->
    (Poly, Poly) {-^ initial values for y,y' -} -> 
    (Poly, Poly) {-^ improved approximates of y and y' -}
solveUncValODE params z (y0, yDer0) =
    (yNext, yDerNext)
    where
    yNext =
        integratePolyMainVar (effMI prec) z y0 yDerNext
    yDerNext =
        integratePolyMainVar (effMI prec) z yDer0 $
            newConstFn cfg domainbox $
                ArithInOut.convertOutEff prec (- gravity)
    prec = paramPrecision params
    domainbox = getDomainBox y0
    cfg = getSizeLimits y0

solveUncTimeValODE ::
    Params ->
    MI.MI {-^ zero with correct precision -} ->
    MI.MI {-^ highest starting time h -} -> -- autonomous system, always 0-h
    (Poly, Poly) {-^ initial values for y,y' -} -> 
    (Poly, Poly) {-^ improved approximates of y and y' -}
solveUncTimeValODE params z h (y0Poly, yDer0Poly) = 
--    unsafePrint
--    (
--        "solveUncTimeValODE:"
--        ++ "\n  y0Poly = " ++ show y0Poly
--        ++ "\n  yDer0Poly = " ++ show yDer0Poly
--        ++ "\n  y0PolyUT0 = " ++ show y0PolyUT0
--        ++ "\n  yDer0PolyUT0 = " ++ show yDer0PolyUT0
--        ++ "\n  yNextUT0 = " ++ show yNextUT0
--        ++ "\n  yDerNextUT0 = " ++ show yDerNextUT0
--        ++ "\n  yNextShiftedUT0 = " ++ show yNextShiftedUT0
--        ++ "\n  yDerNextShiftedUT0 = " ++ show yDerNextShiftedUT0
--        ++ "\n  yNextT0ShiftedU = " ++ show yNextT0ShiftedU
--        ++ "\n  yDerNextT0ShiftedU = " ++ show yDerNextT0ShiftedU
--        ++ "\n  yNextNormalisedT0U = " ++ show yNextNormalisedT0U
--        ++ "\n  yDerNextNormalisedT0U = " ++ show yDerNextNormalisedT0U
--        ++ "\n  yNext = " ++ show yNext
--        ++ "\n  yDerNext = " ++ show yDerNext
--    ) $
    (yNext, yDerNext)
    where
    {- 
        1. In the initial value polynomials change "u" |-> "t0" 
           and add "u" as a new main variable.
    -}
    [y0PolyUT0, yDer0PolyUT0] = map addT [y0Poly, yDer0Poly]
        where
        addT = polyAddMainVar () (effMI prec) "u" (z MI.</\> h) . polyRenameMainVar "t0" 
    {-
        2. Integrate as usual to get a quadratic in u.
    -}
    yNextUT0 =
        integratePolyMainVar (effMI prec) z y0PolyUT0 yDerNextUT0
    yDerNextUT0 =
        integratePolyMainVar (effMI prec) z yDer0PolyUT0 $
            newConstFn cfgUT0 domainboxUT0 $
                ArithInOut.convertOutEff prec (- gravity)
        where
    domainboxUT0 = getDomainBox y0PolyUT0
    cfgUT0 = getSizeLimits y0PolyUT0
    prec = paramPrecision params
    {-
        3. Substitute u |-> u - t0.
    -}
    [yNextShiftedUT0, yDerNextShiftedUT0] = map shiftU [yNextUT0, yDerNextUT0]
        where
        shiftU = substPolyMainVar (effMI prec) z uMt0 
        uMt0 = u <-> t0
        u = newProjection cfgUT0 domainboxUT0 "u"
        t0 = newProjection cfgUT0 domainboxUT0 "t0"
    {-
        4. Swap the order of "u" and "t0" to make "t0" the main variable.
    -}
    [yNextT0ShiftedU, yDerNextT0ShiftedU] 
        = map polySwapFirstTwoVars [yNextShiftedUT0, yDerNextShiftedUT0]
    {-
        5. Substitute t0 |-> t0*u.
    -}
    [yNextNormalisedT0U, yDerNextNormalisedT0U] =
        unsafePrint
        (
            "uTt0 = " ++ show uTt0
        ) $
        map normaliseT0 [yNextT0ShiftedU, yDerNextT0ShiftedU]
        where
        normaliseT0 = substPolyMainVar (effMI prec) z uTt0 
        uTt0 = u <*> t0
        u = newProjection cfgT0U domainboxT0U "u"
        t0 = newProjection cfgT0U domainboxT0U "t0"
        domainboxT0U = getDomainBox yNextT0ShiftedU
        cfgT0U = getSizeLimits yNextT0ShiftedU
    {-
        6. Partially evaluate using t0 = [0,1].
    -}
    [yNext, yDerNext] = map elimT0 [yNextNormalisedT0U, yDerNextNormalisedT0U]
        where
        elimT0 = substPolyMainVarElim (effMI prec) z (z MI.</\> c1)
        c1 = i2mi 1
        i2mi :: Integer -> MI.MI
        i2mi n = ArithInOut.convertOutEff prec n

effMI prec = (prec, (prec, ()))

leftBound (MI.Interval l r) = MI.Interval l l

c1 &&? c2 = 
    case (c1, c2) of
        (Just True, Just True) -> Just True
        (Just False, _) -> Just False
        (_, Just False) -> Just False
        _ -> Nothing
    
