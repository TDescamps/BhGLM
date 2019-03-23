

#*******************************************************************************

surv.curves <- function (y, lp, probs=0.50, mark.time=TRUE, main=" ", 
                         lwd=2, lty=1, col=c(3, 4), add=FALSE) 
{
  library(survival)
  group = as.numeric(cut(lp, c(-Inf, quantile(lp, probs = probs), Inf)))   
  sf = survfit(y ~ group)
  if (!add)
    plot(sf, conf.int=FALSE, mark.time=mark.time, main=main, lwd=lwd, lty=lty, col=col, 
         xlab="Time", ylab="Survival probability")
  else
    lines(sf, conf.int=FALSE, mark.time=mark.time, lwd=lwd, lty=lty, col=col)
  logrank = survdiff(y ~ group)
  p = signif(pchisq(logrank$chisq, df=length(unique(group))-1, lower.tail=F), digits=3)
  legend("topright", paste("p =", p), cex = 0.8, bty = "n")
  return(logrank)
}

Cindex <- function (y, lp) 
{
  ff <- bcoxph(y ~ lp, prior.scale=0, prior.mean=1, verbose=FALSE)
  summary(ff)$concordance
}

#Cindex <- function (y, lp) # very slow for large data
#{
#  time <- y[, 1]
#  status <- y[, 2]
#  x <- lp
#  n <- length(time)
#  ord <- order(time, -status)
#  time <- time[ord]
#  status <- status[ord]
#  x <- x[ord]
#  wh <- which(status == 1)
#  total <- concordant <- 0
#  for (i in wh) {
#    for (j in ((i + 1):n)) {
#      tt <- (time[j] > time[i])
#      if (is.na(tt)) tt <- FALSE
#      if (tt) {
#        total <- total + 1
#        if (x[j] < x[i]) concordant <- concordant + 1
#        if (x[j] == x[i]) concordant <- concordant + 0.5
#      }
#    }
#  }
#  return(list(concordant = concordant, total = total, cindex = concordant/total))
#}


aucCox <- function (y, lp, main = " ", lwd = 2, lty = 1, col = "black", add = FALSE) 
{
  time <- y[, 1]
  status <- y[, 2]
  tt <- sort(unique(time[status == 1]))
  nt <- length(tt)
  x <- lp
  AUCt <- rep(NA, nt)
  numsum <- denomsum <- 0
  for (i in 1:nt) {
    ti <- tt[i]
    Y <- sum(time >= ti)
    R <- which(time > ti)
    xi <- x[time == ti]
    num <- sum(x[R] < xi) + 0.5 * sum(x[R] == xi)
#    num <- 0
#    for (k in 1:length(xi))
#      num <- num + sum(x[R] < xi[k]) + 0.5 * sum(x[R] == xi[k])
    AUCt[i] <- num/(Y - 1)
    numsum <- numsum + num
    denomsum <- denomsum + Y - 1
  }
  AUC <- numsum/denomsum
  if (!add) 
    plot(tt, AUCt, ylim = c(min(AUCt), max(AUCt)), main = main, xlab = "Time", ylab = "AUC(t)", type = "n")
  lines(lowess(data.frame(tt, AUCt)), lwd = lwd, lty = lty, col = col)
  abline(h = 0.5, lty = 3)
  
  return(list(AUCt = data.frame(time = tt, AUC = AUCt), AUC = AUC))
}


# the following functions need the package dynpred
peCox <- function (y, lp, FUN = c("Brier", "KL"), main = "", lwd = 2, lty = 1, col = "black", add = FALSE) 
{
    if (!requireNamespace("dynpred")) install.packages("dynpred")
    library(dynpred)
    FUN <- FUN[1]
    time <- y[, 1]
    status <- y[, 2]
    n <- length(time)
    ord <- order(time, -status)
    time <- time[ord]
    status <- status[ord]
    tt <- sort(unique(time[status == 1]))
    nt <- length(tt)
    
    x <- lp[ord]
    cox1 <- bcoxph(Surv(time, status) ~ x, init = 1, prior = "de",
                   prior.mean = 1, prior.scale = 0, verbose = FALSE)
    if (sum(x^2) == 0) 
      sf <- survfit(cox1, newdata = data.frame(x = x), type = "kalbfl")
    else sf <- survfit(cox1, newdata = data.frame(x = x))
    tt <- sf$time
    survmat <- sf$surv
    
    if (tt[1] > 0) {
      tsurv <- c(0, tt)
      survmat <- rbind(rep(1, n), survmat)
    }
    else tsurv <- tt
    nsurv <- length(tsurv)
    
    coxcens <- coxph(Surv(time, 1 - status) ~ 1)
    ycens <- coxcens[["y"]]
    p <- ncol(ycens)
    tcens <- ycens[, p - 1]
    dcens <- ycens[, p]
    xcens <- coxcens$linear.predictors
    coxcens <- coxph(Surv(tcens, dcens) ~ xcens)
    if (sum(xcens^2) == 0) 
        sfcens <- survfit(coxcens, newdata = data.frame(xcens = xcens), type = "kalbfl")
    else sfcens <- survfit(coxcens, newdata = data.frame(xcens = xcens))
    tcens <- sfcens$time
    censmat <- sfcens$surv
    if (tcens[1] > 0) {
        tcens <- c(0, tcens)
        censmat <- rbind(rep(1, n), censmat)
    }
    ncens <- length(tcens)
    
    tout <- unique(c(tsurv, tcens))
    tout <- sort(tout)
    nout <- length(tout)
    res <- pe(time, status, tsurv, survmat, tcens, censmat, FUN, tout)
    d <- which(res[, 2] == "NaN")
    if (length(d) > 0) res <- res[-d, ]
    
    if (!add)
      plot(res$time[res$Err > 0], res$Err[res$Err > 0], type = "s", ylim = c(0, max(res$Err)),
           lwd = lwd, lty = lty, col = col, main = main, xlab = "Time", ylab = "Prediction error")
    else 
      lines(res$time[res$Err > 0], res$Err[res$Err > 0], type = "s", ylim = c(0, max(res$Err)),
            lwd = lwd, lty = lty, col = col)
    
    return(res)
}


#*******************************************************************************

