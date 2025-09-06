;; Decentralized Prediction Market
;; Allows users to create markets for future events and bet on outcomes
;; Market creators define possible outcomes and set resolution date
;; Users can buy shares in outcomes, with payouts distributed to winners

;; Error constants
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-PARAMS (err u102))
(define-constant ERR-MARKET-RESOLVED (err u103))
(define-constant ERR-MARKET-EXPIRED (err u104))
(define-constant ERR-TOO-EARLY (err u105))
(define-constant ERR-NO-POSITION (err u106))
(define-constant ERR-INSUFFICIENT-BALANCE (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))

(define-data-var market-count uint u0)

(define-map markets
  { market-id: uint }
  {
    creator: principal,
    question: (string-ascii 256),
    outcome-count: uint,
    resolution-block: uint,
    resolved: bool,
    winning-outcome: (optional uint),
    total-staked: uint
  }
)

(define-map outcomes
  { market-id: uint, outcome-id: uint }
  {
    description: (string-ascii 64),
    staked-amount: uint
  }
)

(define-map user-positions
  { market-id: uint, outcome-id: uint, user: principal }
  { amount: uint }
)

;; Helper function to check if market exists and return it
(define-private (get-market-or-fail (market-id uint))
  (map-get? markets { market-id: market-id })
)

;; Helper function to check if outcome exists and return it
(define-private (get-outcome-or-fail (market-id uint) (outcome-id uint))
  (map-get? outcomes { market-id: market-id, outcome-id: outcome-id })
)

;; Create a new prediction market
(define-public (create-market (question (string-ascii 256)) (outcome-count uint) (blocks-until-resolution uint))
  (let
    ((market-id (var-get market-count))
     (resolution-block (+ block-height blocks-until-resolution)))
    
    ;; Validate parameters
    (asserts! (> outcome-count u0) ERR-INVALID-PARAMS)
    (asserts! (<= outcome-count u100) ERR-INVALID-PARAMS) ;; Reasonable upper limit
    (asserts! (> blocks-until-resolution u1000) ERR-INVALID-PARAMS)
    (asserts! (> (len question) u0) ERR-INVALID-PARAMS) ;; Question cannot be empty
    
    ;; Create the market
    (map-set markets
      { market-id: market-id }
      {
        creator: tx-sender,
        question: question,
        outcome-count: outcome-count,
        resolution-block: resolution-block,
        resolved: false,
        winning-outcome: none,
        total-staked: u0
      }
    )
    
    ;; Increment market counter
    (var-set market-count (+ market-id u1))
    
    (ok market-id)
  )
)

;; Define an outcome for a market
(define-public (define-outcome (market-id uint) (outcome-id uint) (description (string-ascii 64)))
  (let
    ((market (unwrap! (get-market-or-fail market-id) ERR-NOT-FOUND)))
    
    ;; Validate conditions
    (asserts! (is-eq tx-sender (get creator market)) ERR-UNAUTHORIZED)
    (asserts! (< outcome-id (get outcome-count market)) ERR-INVALID-PARAMS)
    (asserts! (not (get resolved market)) ERR-MARKET-RESOLVED)
    (asserts! (> (len description) u0) ERR-INVALID-PARAMS) ;; Description cannot be empty
    
    ;; Check if outcome already exists to prevent overwriting
    (asserts! (is-none (map-get? outcomes { market-id: market-id, outcome-id: outcome-id })) ERR-INVALID-PARAMS)
    
    ;; Set the outcome
    (map-set outcomes
      { market-id: market-id, outcome-id: outcome-id }
      { description: description, staked-amount: u0 }
    )
    
    (ok true)
  )
)

;; Stake on a specific outcome
(define-public (stake-on-outcome (market-id uint) (outcome-id uint) (amount uint))
  (let
    ((market (unwrap! (get-market-or-fail market-id) ERR-NOT-FOUND))
     (outcome (unwrap! (get-outcome-or-fail market-id outcome-id) ERR-NOT-FOUND))
     (user-position-key { market-id: market-id, outcome-id: outcome-id, user: tx-sender })
     (user-position (default-to { amount: u0 } (map-get? user-positions user-position-key)))
     (new-amount (+ (get amount user-position) amount))
     (new-staked-amount (+ (get staked-amount outcome) amount))
     (new-total-staked (+ (get total-staked market) amount)))
    
    ;; Validate conditions
    (asserts! (not (get resolved market)) ERR-MARKET-RESOLVED)
    (asserts! (< block-height (get resolution-block market)) ERR-MARKET-EXPIRED)
    (asserts! (> amount u0) ERR-INVALID-PARAMS)
    
    ;; Check for overflow in staking amounts
    (asserts! (>= new-amount amount) ERR-INVALID-PARAMS) ;; Overflow check
    (asserts! (>= new-staked-amount (get staked-amount outcome)) ERR-INVALID-PARAMS) ;; Overflow check
    (asserts! (>= new-total-staked (get total-staked market)) ERR-INVALID-PARAMS) ;; Overflow check
    
    ;; Transfer STX from user to contract - FIXED: Using unwrap! with proper error handling
    (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender)) ERR-TRANSFER-FAILED)
    
    ;; Update user position
    (map-set user-positions user-position-key { amount: new-amount })
    
    ;; Update outcome staked amount
    (map-set outcomes
      { market-id: market-id, outcome-id: outcome-id }
      (merge outcome { staked-amount: new-staked-amount })
    )
    
    ;; Update market total staked
    (map-set markets
      { market-id: market-id }
      (merge market { total-staked: new-total-staked })
    )
    
    (ok true)
  )
)

;; Resolve a market by setting the winning outcome
(define-public (resolve-market (market-id uint) (winning-outcome uint))
  (let
    ((market (unwrap! (get-market-or-fail market-id) ERR-NOT-FOUND)))
    
    ;; Validate conditions
    (asserts! (is-eq tx-sender (get creator market)) ERR-UNAUTHORIZED)
    (asserts! (not (get resolved market)) ERR-MARKET-RESOLVED)
    (asserts! (>= block-height (get resolution-block market)) ERR-TOO-EARLY)
    (asserts! (< winning-outcome (get outcome-count market)) ERR-INVALID-PARAMS)
    
    ;; Ensure the winning outcome actually exists (was defined)
    (asserts! (is-some (map-get? outcomes { market-id: market-id, outcome-id: winning-outcome })) ERR-NOT-FOUND)
    
    ;; Mark market as resolved
    (map-set markets
      { market-id: market-id }
      (merge market { resolved: true, winning-outcome: (some winning-outcome) })
    )
    
    (ok true)
  )
)

;; Claim winnings from a resolved market
(define-public (claim-winnings (market-id uint))
  (let
    ((market (unwrap! (get-market-or-fail market-id) ERR-NOT-FOUND))
     (winning-outcome (unwrap! (get winning-outcome market) ERR-NOT-FOUND))
     (user-position-key { market-id: market-id, outcome-id: winning-outcome, user: tx-sender })
     (user-position (unwrap! (map-get? user-positions user-position-key) ERR-NO-POSITION))
     (winning-outcome-data (unwrap! (get-outcome-or-fail market-id winning-outcome) ERR-NOT-FOUND)))
    
    ;; Validate conditions
    (asserts! (get resolved market) ERR-MARKET-RESOLVED)
    (asserts! (> (get amount user-position) u0) ERR-NO-POSITION)
    
    ;; Calculate reward with proper division handling
    (let
      ((user-stake (get amount user-position))
       (winning-pool (get staked-amount winning-outcome-data))
       (total-pool (get total-staked market))
       (reward (if (> winning-pool u0)
                   (/ (* user-stake total-pool) winning-pool)
                   u0)))
      
      ;; Ensure reward is reasonable (not zero and not exceeding total pool)
      (asserts! (> reward u0) ERR-INVALID-PARAMS)
      (asserts! (<= reward total-pool) ERR-INVALID-PARAMS)
      
      ;; Reset user position to prevent double claiming
      (map-set user-positions user-position-key { amount: u0 })
      
      ;; Transfer winnings to user - FIXED: Proper error handling for transfer
      (unwrap! (as-contract (stx-transfer? reward tx-sender tx-sender)) ERR-TRANSFER-FAILED)
      
      (ok reward)
    )
  )
)

;; Read-only functions for querying contract state

;; Get market information
(define-read-only (get-market (market-id uint))
  (map-get? markets { market-id: market-id })
)

;; Get outcome information
(define-read-only (get-outcome (market-id uint) (outcome-id uint))
  (map-get? outcomes { market-id: market-id, outcome-id: outcome-id })
)

;; Get user position
(define-read-only (get-user-position (market-id uint) (outcome-id uint) (user principal))
  (map-get? user-positions { market-id: market-id, outcome-id: outcome-id, user: user })
)

;; Get total number of markets
(define-read-only (get-market-count)
  (var-get market-count)
)

;; Check if market is active (not resolved and not expired)
(define-read-only (is-market-active (market-id uint))
  (match (map-get? markets { market-id: market-id })
    market (and 
             (not (get resolved market))
             (< block-height (get resolution-block market)))
    false
  )
)