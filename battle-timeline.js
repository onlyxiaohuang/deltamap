(()=>{try{let data=JSON.parse(localStorage.getItem('deltamap-battle-review-v1'));window.DELTAMAP_BATTLE=data?.schema==='deltamap-force-review/v1'?data:null}catch{window.DELTAMAP_BATTLE=null}})();
