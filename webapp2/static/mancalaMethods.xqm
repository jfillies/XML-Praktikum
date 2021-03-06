module namespace m = "mancala/model"; 
import module namespace h = "mancala/helpers" at "mancalaHelpers.xqm";

declare variable $m:instances := db:open("MancalaDB2")//collection;
declare variable $m:default := db:open("MancalaDB2")//collection//game[@gameID="0"];

declare %private function m:getp1Houses($gameID) {
  $m:instances//game[@gameID = $gameID]//slot[@ID>=0 and @ID<6]
};

declare %private function m:getp2Houses($gameID) {
  $m:instances//game[@gameID = $gameID]//slot[@ID>=7 and @ID<13]
};

declare %private function m:newID() as xs:string {
  h:timestamp()
};

declare function m:newGame() as element(game) {
  copy $c := $m:default
  modify 
    replace value of node $c/@gameID with m:newID()
  return $c 
};
(:changed by jan not used any more :)
declare %updating function m:insertnewGame() {
  insert node m:newGame() as last into $m:instances
  };
  
    
declare function m:findlastID() as xs:double{
  
   max($m:instances//game/@gameID)
  
  };



declare %updating function m:insertGame($game as element(game)) {
  insert node $game as last into $m:instances
};

(: Calculates the sum of all counters in the 'Slot' Sequence $s  :)
declare %private function m:sumCounters($s) {
  fn:sum(for $c in $s/count return fn:data($c))
};

declare function m:getHouse($id, $gameID) {
  $m:instances//game[@gameID = $gameID]//slot[@ID=$id]
};



(: Checks if the game has ended // Returns 1 if the row of slots of player 1 is empty
   and returns 2 if the second player's row is empty :)
declare %private function m:finishedCheck($gameID) { 
  if(m:sumCounters(m:getp1Houses($gameID)) = 0) then 
      1
  else 
  if(m:sumCounters(m:getp2Houses($gameID)) = 0) then 
      2
  else 
      0
};


(: Self Explanatory :)
declare %private function m:removeStones($id , $gameID) {
  copy $c := m:getHouse($id, $gameID)
  modify
    replace value of node $c/count with 0
  return $c 
};
declare %private function m:checkPlayerTurn($clickedHouseID, $gameID) {
  let $s := $m:instances//game[@gameID = $gameID]
  let $c := $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count)
    return
      if($s/curplayer = 1) then 
          if($clickedHouseID + $c = 6) then
              <curplayer>1</curplayer> 
          else 
              <curplayer>2</curplayer>
      else
          if($clickedHouseID + $c = 13) then 
              <curplayer>2</curplayer> 
          else 
              <curplayer>1</curplayer>
};
(: Returns the new game state in xml format after the player clicks on a house, but 
    does not consider the opposite house rule // This is done by the 'updatedGameState'
    method, which does the final check and applies the opposite house rule:)
declare function m:intermediateGameState($clickedHouseID, $gameID) {
  let $c := $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count)
  let $s := ($clickedHouseID + $c mod 14)
  return
    <game gameID="{$gameID}" lastCount = "{$c}" clickedHouseID = "{$clickedHouseID}">
    <finished>{m:finishedCheck($gameID)}</finished>
    {m:checkPlayerTurn($clickedHouseID, $gameID)}
	<winner>0</winner>
    {m:moveStones($clickedHouseID, $gameID)}
    </game>
};
(: Receives as input the output of m:intermediateGameState and checks if the 
   opposite house rule applies. Returns the xml representation of the game state
   after a single player move fixed opposite house 
   changed by jan :)
declare function m:finalGameState ($game as element(game)) {
  let $clickedHouse := $game//slot[@ID = $game/@clickedHouseID]
  let $landedHouse := $game//slot[@ID = ($game/@clickedHouseID + $game/@lastCount)]
  let $oppositeHouse := $game//slot[@ID = 12 - $landedHouse/@ID]
  return
	
    if ($clickedHouse/owner = $landedHouse/owner and $landedHouse/data(count) = 1 and $oppositeHouse/data(count) != 0) then 
        copy $c := $game
        modify 
          let $oppositeHouse := $c//slot[@ID = 12 - $landedHouse/@ID]
		  let $landedHouse2 := $c//slot[@ID = ($game/@clickedHouseID + $game/@lastCount)]
		  let $gameover := $c
          let $store := 
              if($clickedHouse/owner = 1) then 
                  $c//slot[@ID = 6] 
              else 
                  $c//slot[@ID = 13]
          return ( 
		  
            replace value of node $store/count with $store/data(count) + $oppositeHouse/data(count) +1,
            replace value of node $oppositeHouse/count with 0,
			replace value of node $landedHouse2/count with 0
          ) 
        return $c                
    else 
	
	$game
};

declare function m:finalGameOver($game as element(game)) {
  let $countstore1 := $game//slot[@ID = 6]/count
  let $countstore2 := $game//slot[@ID = 13]/count
  let $added := (48 - $countstore1 - $countstore2)
  return
	
    if ($game/data(finished) != 0) then 
        copy $c := $game
        modify 
          let $store1 := if($c/data(finished) = 2) then 
									$c//slot[@ID =6]/count 
						 else 
									$c//slot[@ID =6]/data(count) -$added
									
	let $store2 :=	if($c/data(finished) = 1) then 
									$c//slot[@ID =13]/count 
						 else 
									$c//slot[@ID =13]/data(count) -$added	
									
		let $higher := if ( $store1 > $store2 + $added) then 
									$c/data(winner) + 1
						else 
						$c/data(winner) +2
							
	
									
          return ( 
			replace value of node $c//slot[@ID =6]/count with $store1 + $added,
			replace value of node $c//slot[@ID =13]/count with $store2 + $added,
			replace value of node $c/winner with $higher
          ) 
        return $c                
    else 
	
	$game
};




  (:Applies the changes of the updated game state to the database
  eddited by jan see old versions :)
declare %updating function m:executeMove($clickedHouseID,$gameID) {
 
  
  if ($m:instances//game[@gameID = $gameID]/finished = 0) then 
   (m:helpgameover($clickedHouseID,$gameID))
   else 
   m:checkGameOver($gameID)
   
  
};

declare %updating function m:helpgameover($clickedHouseID,$gameID) {
	let $s := $m:instances//game[@gameID = $gameID]
  let $c := $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count)
  return
  
  if ($c = 0) then 

  replace node $m:instances//game[@gameID = $gameID] with (m:finalGameOver($m:instances//game[@gameID = $gameID]))
  
  else
  
  if($s/curplayer = $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(owner)) then  
  
	(replace node $m:instances//game[@gameID = $gameID] with (m:finalGameOver(m:finalGameState((m:intermediateGameState($clickedHouseID, $gameID))))))
  
  else 
	
	 replace node $m:instances//game[@gameID = $gameID] with $m:instances//game[@gameID = $gameID]
  
};


declare %updating function m:finalGameOverCheck($gameID) {
		if($m:instances//game[@gameID = $gameID]/data(finished) = 1) then 
        (replace value of node $m:instances//game[@gameID = $gameID]//slot[@ID = 13]/count with 
        (48 - $m:instances//game[@gameID = $gameID]//slot[@ID = 6]/data(count)),
        m:emptyRow(2,$gameID))
    else if($m:instances//game[@gameID = $gameID]//data(finished) = 2) then 
        (replace value of node $m:instances//game[@gameID = $gameID]//slot[@ID = 6]/count with 
        (48 - $m:instances//game[@gameID = $gameID]//slot[@ID = 13]/data(count)),
         m:emptyRow(1,$gameID))
    else 
        replace node $m:instances with $m:instances
		
		
		
		
		
		
		
		
		(:let $s := $game[@gameID = $gameID]
		return 
		if ($s/finished =1 or $s/finished =2) then 
		replace node $game with (m:checkGameOver($gameID)) 
		else 
		replace node $game with $game
	
		
		  if ($game[@gameID = $gameID]/finished = 1 or $game[@gameID = $gameID]/finished = 2) then 
				replace node $game with (m:checkGameOver($gameID))
			else
			 replace node $game with $game   
		:)
		
		
};


(: by jan for checking if m:gameGameOver() should be invoked :)
declare %updating function m:executeMove2($gameID) {
let $s := $m:instances//game[@gameID = $gameID]
return replace node $m:instances//game[@gameID = $gameID]/slot[@ID=1]  with $s/slot[@ID=1] 
};



declare %private function m:precheckGameOver($gameID) {
let $s := $m:instances//game[@gameID = $gameID]
return 
  if($m:instances//game[@gameID = $gameID]/data(finished) != 0) then 
         1
    else 
         0		
		};
		
		
		
declare %updating function m:checkGameOver($gameID) {
  if($m:instances//game[@gameID = $gameID]/data(finished) = 1) then 
        (replace value of node $m:instances//game[@gameID = $gameID]//slot[@ID = 13]/count with 
        (48 - $m:instances//game[@gameID = $gameID]//slot[@ID = 6]/data(count)),
        m:emptyRow(2,$gameID))
    else if($m:instances//game[@gameID = $gameID]//data(finished) = 2) then 
        (replace value of node $m:instances//game[@gameID = $gameID]//slot[@ID = 6]/count with 
        (48 - $m:instances//game[@gameID = $gameID]//slot[@ID = 13]/data(count)),
         m:emptyRow(1,$gameID))
    else 
        replace node $m:instances with $m:instances
};




declare %updating function m:emptyRow($owner, $gameID) {
  for $s in $m:instances//game[@gameID=$gameID]//slot[@ID != 13 and @ID != 6]
  where $s/owner = $owner
  return replace value of node $s/count with 0
};


  (:Empties the clicked house and then moves the stones accordingly
    Returns a sequence of all the slots (houses and stores) with updated counts
  changed by jan for skipp oposite store count increase not done after hitting the opposite store:)
 
declare %private function m:moveStones($clickedHouseID, $gameID) {
 let $a := $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count) 
  let $c := if (($a mod 26) >12 )then 
		$m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count)+1
	else if (($a mod 26)=0 )then 
		 $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count) +2
	else 
		$m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count)
  for $s in $m:instances//game[@gameID = $gameID]//slot
  
  return 
	
    if(($clickedHouseID + $c) > 13) then 
        if(($s/@ID < $clickedHouseID) and ($s/@ID > (($clickedHouseID + $c) mod 13)) and $c <13) then 
            $s 
		(:else if (($s/@ID < $clickedHouseID) and ($s/@ID > (($clickedHouseID + $c) mod 26)) and $c >12) then 
          :)  
			
			
			
			
			(:not done jet y let $c not working but dosn't matter because we have not figgured 
			out how to set more the 12 stones then you have to increade the count after you hit the opposite store:)
			
		else if ($s[@type = 'store'] and $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(owner) != $s/data(owner))then 
			let $a := $c
			return $s
			
        else if ($s/@ID = $clickedHouseID and ($c)<13) then 
            m:removeStones($clickedHouseID, $gameID)  
		else if ($s/@ID = $clickedHouseID and ($c)<26) then 
			copy $c := $s
            modify 
            (
			replace value of node $c/count with  1
			)
            return $c
		else if ($s/@ID = $clickedHouseID and ($c)>25) then
			copy $c := $s		
			 modify 
            (
			replace value of node $c/count with  2
			)
            return $c
		
        else
            copy $c := $s
            modify 
            (
              replace value of node $c/count with $s/data(count) + 1
            )
            return $c
    else 
        if(($s/@ID < $clickedHouseID) or ($s/@ID > ($clickedHouseID + $c))) then 
            $s 
        else if ($s/@ID = $clickedHouseID) then 
            m:removeStones($clickedHouseID, $gameID)
			
			(:not done jet y let $c not working but dosn't matter because we have not figgured 
			out how to set more the 12 stones then you have to increade the count after you hit the opposite store:)
		else if ($s[@type ='store'] and $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/owner != $s/owner)then 
			let $c := $m:instances//game[@gameID=$gameID]//slot[@ID = $clickedHouseID]/data(count) +1
			return $s
        else 
            copy $c := $s
				
            modify 
            (
              replace value of node $c/count with $s/data(count) + 1
            )
            return $c     
};
