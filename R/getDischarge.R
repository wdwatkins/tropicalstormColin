# get the data

library(dataRetrieval)
library(dplyr)

retryNWIS <- function(..., retries=3){
  
  safeWQP = function(...){
    result = tryCatch({
      readNWISdata(...)
    }, error = function(e) {
      if(e$message == 'Operation was aborted by an application callback'){
        stop(e)
      }
      return(NULL)
    })
    return(result)
  }
  retry = 1
  while (retry < retries){
    result = safeWQP(...)
    if (!is.null(result)){
      retry = retries
    } else {
      message('query failed, retrying')
      retry = retry+1
    }
  }
  return(result)
}

getDischarge <- function(bbox = "-85,29,-80,33.9", minDrainage = "100", start="2016-06-4", end="2016-06-06"){
  
  #find sites within lat/lon box, >100 km^2 drainage
  #expanded output option didnt seem to provide anything extra?
  sites <- whatNWISsites(bbox=bbox,siteType="ST",siteOutput="Expanded",drainAreaMin="100", parameterCd="00060")
  
  #get the actual data, converted to numeric format
  siteNos <- sites$site_no
  startDate <- as.Date(start)
  endDate <- as.Date(end)
  
  #loop over sites, get data, concatenate
  #leave out sites with no data or sample rates > 15 min (192 samples/2 days)
  
  allQ <- data.frame() 
  
  for (site in siteNos)
  {
    siteQ <- retryNWIS(service = "iv",convertType = TRUE, sites=site, 
                       startDate=startDate, endDate=endDate, parameterCd="00060")
    #print(dim(siteQ))
    siteQ <- renameNWISColumns(siteQ)
    
    #coercing column names to be the same; might want to check if any sites besides the tallahassee one has neg #s?
    #print a notification first though
    if( identical(names(allQ),names(siteQ)) == FALSE && length(names(siteQ)) == 6)
    {
      names(siteQ) <- c("agency_cd","site_no","dateTime","Flow_Inst","Flow_Inst_cd","tz_cd")
      print(paste("site",site,"had different column names; they were changed"))
    }
    
    if (nrow(siteQ) > 1) #first check that there is actually data in siteQ
    {
      sampRate = siteQ$dateTime[2] - siteQ$dateTime[1] #check that the sample rate is every 15 min
      if ( sampRate == 15)
      {
        #print(site)
        #print(dim(siteQ))
        allQ <- rbind(allQ,siteQ)
      }
    }
  }
  
  allQ_info <- left_join(allQ, sites, by="site_no") %>% 
    select(site_no, dateTime, Flow_Inst, station_nm, dec_lat_va, dec_long_va)
  
  return(allQ_info)
}

Q <- getDischarge(start="2016-06-4", end="2016-06-09") #test the function