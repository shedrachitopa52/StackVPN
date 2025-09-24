;; ClariNet Decentralized VPN on Stacks (Clarity)
;; Author: Generated for user
;; License: MIT

;; Import core library functions
(define-trait sip-010-trait
  (
    (transfer? (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

(define-constant CONTRACT_DEPLOYER tx-sender)

(define-data-var owner principal tx-sender) ;; contract deployer is owner

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NODE-NOT-FOUND (err u101))
(define-constant ERR-SESSION-NOT-FOUND (err u102))
(define-constant ERR-INACTIVE-NODE (err u103))
(define-constant ERR-INSUFFICIENT-PREPAID (err u104))
(define-constant ERR-ALREADY-ACTIVE (err u105))
(define-constant ERR-BAD-RATING (err u106))
(define-constant ERR-MIN-STAKE (err u107))
(define-constant ERR-NOT-OWNER (err u108))
(define-constant ERR-NO-EARNINGS (err u109))
(define-constant ERR-INSUFFICIENT-STAKE (err u110))
(define-constant ERR-ACTIVE-NODE (err u111))

;; Data vars for incremental IDs
(define-data-var next-node-id uint u1)
(define-data-var next-session-id uint u1)

;; Map of vpn nodes
;; key: { id: uint }
;; value fields:
;; owner: principal
;; price-per-block: uint
;; bandwidth: uint
;; location: (string-utf8 30)
;; stake: uint
;; active: bool
;; total-rating: uint
;; rating-count: uint
;; earnings: uint
(define-map vpn-nodes
  { id: uint }
  {
    owner: principal,
    price-per-block: uint,
    bandwidth: uint,
    location: (string-utf8 30),
    stake: uint,
    active: bool,
    total-rating: uint,
    rating-count: uint,
    earnings: uint
  })

;; Map of sessions
;; key: { session-id: uint }
;; value fields:
;; user: principal
;; node-id: uint
;; start-block: uint
;; rate: uint
;; prepaid: uint
;; active: bool
(define-map vpn-sessions
  { session-id: uint }
  {
    user: principal,
    node-id: uint,
    start-block: uint,
    rate: uint,
    prepaid: uint,
    active: bool
  })

;; ---------------------------
;; Helper read-only functions
;; ---------------------------

(define-read-only (get-block-height)
  stacks-block-height
)

(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-read-only (get-next-node-id)
  (ok (var-get next-node-id))
)

(define-read-only (get-next-session-id)
  (ok (var-get next-session-id))
)

(define-read-only (get-node (node-id uint))
  (match (map-get? vpn-nodes { id: node-id })
    entry (ok entry)
    (err ERR-NODE-NOT-FOUND))
)

(define-read-only (get-session (session-id uint))
  (match (map-get? vpn-sessions { session-id: session-id })
    entry (ok entry)
    (err ERR-SESSION-NOT-FOUND))
)

;; ---------------------------
;; Node lifecycle
;; ---------------------------

;; Minimum stake required (example: 100 STX)
(define-constant MIN_STAKE u100) ;; Stacks uses micro-STX? adjust as needed; here symbolic

;; Register a node caller must transfer `stake` STX to the contract in the same call
(define-public (register-node (price-per-block uint) (bandwidth uint) (location (string-utf8 30)) (stake uint))
  (begin
    ;; enforce minimum stake
    (asserts! (>= stake MIN_STAKE) (err ERR-MIN-STAKE))
    ;; transfer stake from caller to contract
    (let ((transfer-result (stx-transfer? stake tx-sender (as-contract tx-sender))))
      (asserts! (is-ok transfer-result) (err ERR-MIN-STAKE))
      (asserts! (unwrap-panic transfer-result) (err ERR-MIN-STAKE))
      (let ((nid (var-get next-node-id)))
        (map-set vpn-nodes { id: nid }
          {
            owner: tx-sender,
            price-per-block: price-per-block,
            bandwidth: bandwidth,
            location: location,
            stake: stake,
            active: true,
            total-rating: u0,
            rating-count: u0,
            earnings: u0
          })
        (var-set next-node-id (+ nid u1))
        (ok nid)))
  ))

;; Owner (node owner) can update price, bandwidth, location
(define-public (update-node (node-id uint) (price-per-block uint) (bandwidth uint) (location (string-utf8 30)))
  (let ((entry (map-get? vpn-nodes { id: node-id })))
    (match entry
      node
      (begin
        (asserts! (is-eq (get owner node) tx-sender) (err ERR-UNAUTHORIZED))
        ;; rewrite with updated fields (keep stake, ratings, earnings, active)
        (map-set vpn-nodes { id: node-id }
          {
            owner: (get owner node),
            price-per-block: price-per-block,
            bandwidth: bandwidth,
            location: location,
            stake: (get stake node),
            active: (get active node),
            total-rating: (get total-rating node),
            rating-count: (get rating-count node),
            earnings: (get earnings node)
          })
        (ok true)
      )
      (err ERR-NODE-NOT-FOUND))
  )
)

;; Node owner can deactivate (toggle) node; if deactivating, node stops receiving new sessions.
(define-public (set-node-active (node-id uint) (active bool))
  (let ((entry (map-get? vpn-nodes { id: node-id })))
    (match entry
      node
      (begin
        (asserts! (is-eq (get owner node) tx-sender) (err ERR-UNAUTHORIZED))
        (map-set vpn-nodes { id: node-id }
          {
            owner: (get owner node),
            price-per-block: (get price-per-block node),
            bandwidth: (get bandwidth node),
            location: (get location node),
            stake: (get stake node),
            active: active,
            total-rating: (get total-rating node),
            rating-count: (get rating-count node),
            earnings: (get earnings node)
          })
        (ok true)
      )
      (err ERR-NODE-NOT-FOUND))
  )
)


(define-public (withdraw-stake (node-id uint) (amount uint))
  (let ((entry (map-get? vpn-nodes { id: node-id })))
    (match entry
      node
      (begin
        (asserts! (is-eq (get owner node) tx-sender) (err ERR-UNAUTHORIZED))
        (asserts! (is-eq (get active node) false) (err ERR-ACTIVE-NODE))
        (let ((current-stake (get stake node)))
          (asserts! (>= current-stake amount) (err ERR-INSUFFICIENT-STAKE))
          ;; reduce stake
          (map-set vpn-nodes { id: node-id }
            {
              owner: (get owner node),
              price-per-block: (get price-per-block node),
              bandwidth: (get bandwidth node),
              location: (get location node),
              stake: (- current-stake amount),
              active: (get active node),
              total-rating: (get total-rating node),
              rating-count: (get rating-count node),
              earnings: (get earnings node)
            })
          ;; transfer amount from contract to node owner
          (let ((transfer-result (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (asserts! (is-ok transfer-result) (err ERR-INSUFFICIENT-STAKE))
            (asserts! (unwrap-panic transfer-result) (err ERR-INSUFFICIENT-STAKE))
            (ok true))
        )
      )
      (err ERR-NODE-NOT-FOUND))
  )
)

;; ---------------------------
;; Sessions & Payments
;; ---------------------------

;; Start a session by prepaying `blocks * price-per-block` into contract. Returns session-id.
(define-public (start-session (node-id uint) (blocks uint))
  (let ((node-opt (map-get? vpn-nodes { id: node-id })))
    (match node-opt
      node
      (begin
        (asserts! (get active node) (err ERR-INACTIVE-NODE))
        (let ((price (get price-per-block node))
              (cost (* blocks price)))
          ;; transfer prepaid from user to contract
          (let ((transfer-result (stx-transfer? cost tx-sender (as-contract tx-sender))))
            (asserts! (is-ok transfer-result) (err ERR-INSUFFICIENT-PREPAID))
            (asserts! (unwrap-panic transfer-result) (err ERR-INSUFFICIENT-PREPAID)))
          (let ((sid (var-get next-session-id)))
            (map-set vpn-sessions { session-id: sid }
              {
                user: tx-sender,
                node-id: node-id,
                start-block: (get-block-height),
                rate: price,
                prepaid: cost,
                active: true
              })
            (var-set next-session-id (+ sid u1))
            (ok sid)
          )
        )
      )
      (err ERR-NODE-NOT-FOUND))
  )
)

;; End a session, calculate used amount based on elapsed blocks and transfer used to node owner; refund remainder to user.
(define-public (end-session (session-id uint))
  (let ((session (unwrap! (map-get? vpn-sessions { session-id: session-id }) (err ERR-SESSION-NOT-FOUND))))
    (begin
      ;; Verify session is active and user is authorized
      (asserts! (get active session) (err ERR-SESSION-NOT-FOUND))
      (asserts! (or (is-eq (get user session) tx-sender) (is-eq (var-get owner) tx-sender)) (err ERR-UNAUTHORIZED))
      
      (let ((current-block (get-block-height))
            (start-block (get start-block session))
            (rate (get rate session))
            (prepaid (get prepaid session))
            (node-id (get node-id session)))
        
        ;; Calculate usage and refund
        (let ((elapsed (if (> current-block start-block) (- current-block start-block) u0))
              (total-cost (* elapsed rate))
              (used (if (>= total-cost prepaid) prepaid total-cost))
              (refund (- prepaid used)))
          
          (let ((node (unwrap! (map-get? vpn-nodes { id: node-id }) (err ERR-NODE-NOT-FOUND))))
            
            ;; Update node earnings
            (map-set vpn-nodes { id: node-id }
              {
                owner: (get owner node),
                price-per-block: (get price-per-block node),
                bandwidth: (get bandwidth node),
                location: (get location node),
                stake: (get stake node),
                active: (get active node),
                total-rating: (get total-rating node),
                rating-count: (get rating-count node),
                earnings: (+ (get earnings node) used)
              })
            
            ;; Mark session inactive
            (map-set vpn-sessions { session-id: session-id }
              {
                user: (get user session),
                node-id: node-id,
                start-block: start-block,
                rate: rate,
                prepaid: prepaid,
                active: false
              })
            
            ;; Process refund
            (if (> refund u0)
              (let ((transfer-result (stx-transfer? refund (as-contract tx-sender) (get user session))))
                (asserts! (is-ok transfer-result) (err ERR-INSUFFICIENT-PREPAID))
                (asserts! (unwrap-panic transfer-result) (err ERR-INSUFFICIENT-PREPAID))
                (ok refund))
              (ok u0))))))))
      
  


;; Node owner withdraws accumulated earnings (collected in contract)
(define-public (withdraw-earnings (node-id uint) (amount uint))
  (let ((node-opt (map-get? vpn-nodes { id: node-id })))
    (match node-opt
      node
      (begin
        (asserts! (is-eq (get owner node) tx-sender) (err ERR-UNAUTHORIZED))
        (let ((earn (get earnings node)))
          (asserts! (>= earn amount) (err ERR-NO-EARNINGS))
          ;; reduce earnings
          (map-set vpn-nodes { id: node-id }
            {
              owner: (get owner node),
              price-per-block: (get price-per-block node),
              bandwidth: (get bandwidth node),
              location: (get location node),
              stake: (get stake node),
              active: (get active node),
              total-rating: (get total-rating node),
              rating-count: (get rating-count node),
              earnings: (- earn amount)
            })
          ;; transfer from contract to node owner
          (let ((transfer-result (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (asserts! (is-ok transfer-result) (err ERR-NO-EARNINGS))
            (asserts! (unwrap-panic transfer-result) (err ERR-NO-EARNINGS))
            (ok true))
        )
      )
      (err ERR-NODE-NOT-FOUND))
  )
)

;; ---------------------------
;; Rating & Reputation
;; ---------------------------

;; Users can rate nodes (1..5). Ratings accumulate to compute average externally.
(define-public (rate-node (node-id uint) (score uint))
  (let ((node-opt (map-get? vpn-nodes { id: node-id })))
    (begin
      (asserts! (and (>= score u1) (<= score u5)) (err ERR-BAD-RATING))
      (match node-opt
        node
          (begin 
            (map-set vpn-nodes 
              { id: node-id }
              {
                owner: (get owner node),
                price-per-block: (get price-per-block node),
                bandwidth: (get bandwidth node),
                location: (get location node),
                stake: (get stake node),
                active: (get active node),
                total-rating: (+ (get total-rating node) score),
                rating-count: (+ (get rating-count node) u1),
                earnings: (get earnings node)
              })
            (ok true))
        (err ERR-NODE-NOT-FOUND)))))


;; Read-only helper to get average rating (returns tuple (err uxxx) or (ok uint) where uint is avg = total-rating / rating-count)
(define-read-only (get-node-rating (node-id uint))
  (let ((node-opt (map-get? vpn-nodes { id: node-id })))
    (match node-opt
      node
      (let ((count (get rating-count node))
            (total (get total-rating node)))
        (if (> count u0)
            (ok (/ total count))
            (ok u0)))
      (err ERR-NODE-NOT-FOUND))
  )
)

;; ---------------------------
;; Slashing (admin-controlled for now)
;; ---------------------------

;; Contract owner can slash a node's stake (e.g., for misbehavior) and assign penalty to a beneficiary (user affected).
(define-public (slash-node (node-id uint) (amount uint) (beneficiary principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR-NOT-OWNER))
    (let ((node-opt (map-get? vpn-nodes { id: node-id })))
      (match node-opt
        node
        (let ((current-stake (get stake node)))
          (asserts! (>= current-stake amount) (err ERR-INSUFFICIENT-STAKE))
          ;; reduce stake
          (map-set vpn-nodes { id: node-id }
            {
              owner: (get owner node),
              price-per-block: (get price-per-block node),
              bandwidth: (get bandwidth node),
              location: (get location node),
              stake: (- current-stake amount),
              active: (get active node),
              total-rating: (get total-rating node),
              rating-count: (get rating-count node),
              earnings: (get earnings node)
            })
          ;; transfer slashed amount to beneficiary
          (let ((transfer-result (stx-transfer? amount (as-contract tx-sender) beneficiary)))
            (asserts! (is-ok transfer-result) (err ERR-INSUFFICIENT-STAKE))
            (asserts! (unwrap-panic transfer-result) (err ERR-INSUFFICIENT-STAKE)))
          (ok true)
        )
        (err ERR-NODE-NOT-FOUND))
    )
  )
)

;; ---------------------------
;; Administrative / Owner functions
;; ---------------------------

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR-NOT-OWNER))
    (var-set owner new-owner)
    (ok true)
  )
)

;; Emergency withdraw by owner (drains contract to owner) use only for development/testing
(define-public (owner-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR-NOT-OWNER))
    (let ((transfer-result (stx-transfer? amount (as-contract tx-sender) tx-sender)))
      (asserts! (is-ok transfer-result) (err ERR-NOT-OWNER))
      (asserts! (unwrap-panic transfer-result) (err ERR-NOT-OWNER))
      (ok true))
  )
)

;; ---------------------------
;; End contract
;; ---------------------------

