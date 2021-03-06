rm(list = ls())
library(doSNOW)
library(foreach)
library(gbm)

speedDistribution <- function(trip)
{
  speed <- 3.6*sqrt(diff(trip$x,20,1)^2 + diff(trip$y,20,1)^2)/20
  return(quantile(speed, seq(0.05,1, by = 0.05)))
}

set.seed(25)
drivers = list.files("drivers")
randomDrivers = sample(drivers, size = 5)


target = 0
names(target) = "target"

cl <- makeCluster(4, type = "SOCK")
registerDoSNOW(cl)

refData <- foreach(driver = iter(randomDrivers), .combine = rbind)%dopar%
{
  dirPath = paste0("drivers/", driver, '/')
  ref.data <- NULL
  for(i in 1:200)
  {
    trip = read.csv(paste0(dirPath, i, ".csv"))
    features = c(speedDistribution(trip), target)
    ref.data = rbind(ref.data, features)
  }
  ref.data
}


n.trees <- 5000
target = 1
names(target) = "target"
submission = NULL
submission <- foreach(driver = iter(drivers), .combine = rbind,
                      .packages = "gbm") %dopar%
{
  print(driver)
  dirPath = paste0("drivers/", driver, '/')
  currentData = NULL
  for(i in 1:200)
  {
    trip = read.csv(paste0(dirPath, i, ".csv"))
    features = c(speedDistribution(trip), target)
    currentData = rbind(currentData, features)
  }
  train = rbind(currentData, refData)
  train = as.data.frame(train)
  g = gbm(target ~ ., data=train,n.trees = n.trees, distribution = "bernoulli")
  currentData = as.data.frame(currentData)
  p =predict(g, currentData, n.trees = n.trees, type = "response")
  labels = sapply(1:200, function(x) paste0(driver,'_', x))
  result = cbind(labels, p)
#   submission = rbind(submission, result)
}

stopCluster(cl)

colnames(submission) = c("driver_trip","prob")
write.csv(submission, "submissions/submission_gbm_speedquantile.csv", row.names=F, quote=F)
