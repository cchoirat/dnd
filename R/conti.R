##############################
## required packages:
##############################
# To install "causalTree", need to use the following:
# install.packages("devtools")
# library(devtools)
# install_github("susanathey/causalTree")
# library(causalTree)
# library(mvtnorm)
# library(rpart.utils)
#library(sensitivitymv)

###############################################################
### as one function -> (1) C matrix and (2) subgroup.num (indicates which individual is in which terminal subgroup)
tree.stru = function(tree, x) {
  library(rpart.utils)
  # rpart.rules.table(tree)
  # rpart.subrules.table(tree)

  tree.frame = tree$frame
  nodes = as.numeric(rownames(tree.frame))
  terminal.node.ind = (tree.frame$var == "<leaf>")
  terminal.node.num = sum(terminal.node.ind)
  terminal.nodes = nodes[terminal.node.ind]

  if (length(nodes) == 1) {
    matrix.C = matrix(1, nrow = 1, ncol = 1)
    rownames(matrix.C) = 1
    colnames(matrix.C) = 1
    x$subgroup.num = rep(1, length(x[, 1]))
    return(list(C = matrix.C, new.x = x))
  }

  parent.node.list = vector("list", terminal.node.num)
  for (i in 1:terminal.node.num) {
    temp.t.node.num = (nodes[terminal.node.ind == 1])[i]
    temp.parent.node.num = c()
    temp.parent.node.num[1] = temp.t.node.num
    j = 1
    temp.p.node.end = 0
    while (temp.p.node.end != 1) {
      j = j + 1
      if (temp.t.node.num %% 2 == 0) {
        temp.p.node.end = temp.t.node.num / 2
        temp.parent.node.num[j] = temp.p.node.end
      } else{
        temp.p.node.end = (temp.t.node.num - 1) / 2
        temp.parent.node.num[j] = temp.p.node.end
      }
      temp.t.node.num = temp.p.node.end
    }
    parent.node.list[[i]] = temp.parent.node.num
  }
  ## create C matrix
  matrix.C = matrix(0, nrow = length(nodes), ncol = length(terminal.nodes))
  rownames(matrix.C) = nodes
  colnames(matrix.C) = terminal.nodes

  for (i in 1:terminal.node.num) {
    matrix.C[rownames(matrix.C) %in% parent.node.list[[i]], i] = 1
  }
  matrix.C = matrix.C[-1, ] # delete the first row


  ## assign the terminal node name
  decision.rule = rpart.rules.table(tree)
  var.rule = rpart.subrules.table(tree)

  x$subgroup.num = rep(NA, length(x[, 1]))
  for (i in 1:terminal.node.num) {
    temp.t.node = terminal.nodes[i]
    temp.d.rule = decision.rule[decision.rule$Rule == temp.t.node, "Subrule"]

    temp.v.rule = var.rule[var.rule$Subrule %in% temp.d.rule,]
    temp.ind.matrix = matrix(NA, nrow = length(temp.d.rule), ncol = length(x[, 1]))
    for (j in 1:length(temp.d.rule)) {
      temp.var.name = temp.v.rule$Variable[j]
      x.column.num = which(colnames(x) == temp.var.name)
      if (is.na(temp.v.rule$Less[j]) == 1) {
        temp.ind.matrix[j, ] = (x[, x.column.num] >= as.numeric(as.character(temp.v.rule$Greater[j])))
      } else{
        temp.ind.matrix[j, ] = (x[, x.column.num] < as.numeric(as.character(temp.v.rule$Less[j])))
      }
    }
    temp.ind = apply(temp.ind.matrix, 2, prod)
    x[temp.ind == 1, "subgroup.num"] = rep(temp.t.node, sum(temp.ind))
  }
  return(list(C = matrix.C, new.x = x))
}

### Exp. and Var. when the sensitivity parameter is gamma.
wilcoxSenMoments = function(N, gamma) {
  #Computes null expectation and variance of Wilcoxon's statistic
  #in a sensitivity analysis with parameter Gamma
  #Uses formula (4.11) in Rosenbaum (2002) Observational Studies
  pplus.u = gamma / (1 + gamma)
  pplus.l = 1 / (1 + gamma)
  expect.u = pplus.u * N * (N + 1) / 2
  expect.l = pplus.l * N * (N + 1) / 2
  vari = pplus.u * (1 - pplus.u) * N * (N + 1) * (2 * N + 1) / 6
  list(expect.upper = expect.u,
       expect.lower = expect.l,
       var = vari)
}

### Confidence interval for the population mean
get.tau.vector.wilcox = function(data,
                                 gamma = 0.001,
                                 grid.size = 21) {
  wilcox.res = wilcox.test(
    matched.data$y_t,
    matched.data$y_c,
    paired = T,
    alternative = "two.sided",
    conf.int = T,
    conf.level = 1 - gamma
  )
  conf.int.vec = seq(
    wilcox.res$conf.int[1],
    wilcox.res$conf.int[2],
    by = (wilcox.res$conf.int[2] - wilcox.res$conf.int[1]) / (grid.size - 1)
  )
  return(conf.int.vec)
}

########################################################
### Load "sim_data.csv" - each entry represents one exactly matched pair.
### x1 is the only effect modifier
### y_t | x1=1 ~ N(0.7, sqrt(1/2))
### y_t | x1=0 ~ N(0.3, sqrt(1/2))
### y_c ~ N(0, sqrt(1/2))

# matched.data=read.csv("sim_data.csv")[,-1]
# n=dim(matched.data)[1] # number of pairs
# m=dim(matched.data)[2]
# # create a data matrix so that each entry has one individual.
# full.data=c(matched.data[,1], matched.data[,2])
# full.data=cbind(full.data, c(rep(1, n), rep(0, n)), rbind(matched.data[,3:m], matched.data[,3:m]))
# full.data=as.data.frame(full.data)
# colnames(full.data)[1:2]=c("y_obs", "z")
# ########################################################
# ##### Select training sample & Est sample (25% vs. 75%)
# training.data.index=sample(1:n, n/4, replace=F)
# train=c(training.data.index, training.data.index+n)
#
# tra.matched.data=matched.data[training.data.index, ]
# test.matched.data=matched.data[-training.data.index,]
# tra.matched.data=as.data.frame(tra.matched.data)
# test.matched.data=as.data.frame(test.matched.data)
#
# traData=full.data[train,] # training data
# testData=full.data[-train, ] # test data
#
# ################################################################################################
# ######### Discovering tree structures in the first subsample (training sample)
# ################################################################################################
# ### training sample -> Create tree using causaltree (CT)
# tree=causalTree(y_obs ~ x1+x2+x3+x4+x5, data=traData, treatment = traData$z, HonestSampleSize=length(testData[,1]),
#                 split.Rule = "CT", cv.option = "CT", split.Honest = T, cv.Honest = T, split.Bucket = F, xval = 5,
#                 cp = 0, minsize = 50, propensity = 0.5)
#
# opcp=tree$cptable[,1][which.min(tree$cptable[,4])]
# opfit=prune(tree, opcp) ## obtained tree from a training sample
#
# # ### training sample -> Create tree using CART
# # res=rpart((y_t-y_c) ~ x1+x2+x3+x4+x5, data=tra.matched.data, method="anova", control=rpart.control(cp=0))
# # opt.cp=res$cptable[,1][which.min(res$cptable[,4])]
# # pruned=prune(res, opt.cp) ## obtained tree from a training sample
# #
# # ### chosing a tree with more terminal nodes
# # if(sum(opfit$frame$var=="<leaf>") >= sum(pruned$frame$var=="<leaf>")){
# #   test.tree.stru=tree.stru(opfit, testData)
# # }else{
# #   test.tree.stru=tree.stru(pruned, test.matched.data)
# # }
# # by default, use a tree from CT
#
# test.tree.stru=tree.stru(opfit, testData)
# subgroup.num=test.tree.stru$new.x$subgroup.num
# unique.subg=as.numeric(colnames(test.tree.stru$C))
# num.of.subgroups=length(unique.subg)
#
#
# ########################################################################################################
# ##### Use the second sample (test sample)
# ##### test of effect modification when Gamma=1 (under no unmeasured confounder assumption)
# ########################################################################################################
# C=test.tree.stru$C
#
# # set significance levels
# tot.signif=0.05 # total significance level = gamma (conf. level.) + alpha (signficance level for testing)
# gamma=0.01
# alpha=tot.signif-gamma
#
# # Since the population treatment effect size (tau) is not known, we estimate the 100(1-gamma)% CI of tau.
# tau.vec=get.tau.vector.wilcox(test.matched.data, gamma=gamma)
#
# null.values=matrix(NA, nrow=num.of.subgroups, ncol=3)
# for(i in 1:num.of.subgroups){
#   ## null values
#   null.values[i,]=as.vector(unlist(wilcoxSenMoments(sum(subgroup.num==unique.subg[i])/2, gamma=1)))
# }
# mu=null.values[,1]; V=null.values[,3];
# if(dim(C)[1]==1){
#   theta0= mu
#   sigma0= V
#   corr0= C
# }else{
#   theta0= C %*% mu
#   sigma0= C %*% diag(V) %*% t(C)
#   corr0=sigma0/sqrt(outer(diag(sigma0),diag(sigma0),"*"))
# }
#
# max.dev.vec=rep(NA, length(tau.vec))
# dev.mat=matrix(NA, nrow=length(tau.vec), ncol=dim(C)[1])
# for(j in 1:length(tau.vec)){
#   temp.tau=tau.vec[j]
#
#   ## compute the test statistic T for each subgroup
#   temp.t.vec=rep(NA, num.of.subgroups)
#   for(i in 1:num.of.subgroups){
#     subgroup=testData[subgroup.num==unique.subg[i],]
#     treated.y=subgroup[1:(length(subgroup[,1])/2),1]
#     control.y=subgroup[-(1:(length(subgroup[,1])/2)),1]
#     temp.t.vec[i]=wilcox.test(treated.y-temp.tau, control.y, paired=T, alternative="two.sided")$statistic
#   }
#
#   ## compute the comparisons using S=CT
#   temp.test= C %*% temp.t.vec
#   if(dim(C)[1]==1){
#     temp.deviate=(temp.test-theta0)/sqrt(sigma0)
#   }else{
#     temp.deviate=(temp.test-theta0)/sqrt(diag(sigma0))
#   }
#   dev.mat[j,]=temp.deviate
#   max.deviate=max(abs(temp.deviate))
#   max.dev.vec[j]=max.deviate
# }
# ## Critical value at alpha.
# if(dim(C)[1]==1){
#   critical.val=qnorm(1-alpha/2)
# }else{
#   critical.val=qmvnorm(1-alpha/2, mean=rep(0, length(corr0[,1])), corr=corr0)$quantile
# }
#
# dev.res.mat=cbind(dev.mat, max.dev.vec, rep(critical.val, length(max.dev.vec))) #
# colnames(dev.res.mat)=c(rownames(C), "Max", "kappa")
# dev.res.mat=as.data.frame(dev.res.mat)
# dev.res.mat$tau=tau.vec
# dev.res.mat
#
# ########################################################################
# ########## Sensitivity analysis with various values of Gamma. ##########
# ########################################################################
# sensi.param.vec=c(1, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3) # need to specify this vector.
#
# # Instead of estimating the 100(1-gamma)% CI of tau, choose a wide enough interval for tau
# tau.vec=seq(0,1, by=0.01)
#
# sensi.mat=matrix(NA, nrow=length(sensi.param.vec), ncol=dim(C)[1]+2)
# for(k in 1:length(sensi.param.vec)){
#   Gamma=sensi.param.vec[k]
#
#   null.values=matrix(NA, nrow=num.of.subgroups, ncol=3)
#   for(i in 1:num.of.subgroups){
#     ## null values
#     null.values[i,]=as.vector(unlist(wilcoxSenMoments(sum(subgroup.num==unique.subg[i])/2, gamma=Gamma)))
#   }
#   mu.upper=null.values[,1] # lower bound of Exp.
#   mu.lower=null.values[,2] # upper bound of Exp.
#   V=null.values[,3]
#   if(dim(C)[1]==1){
#     theta0.upper= mu.upper
#     theta0.lower= mu.lower
#     sigma0= V
#     corr0= C
#   }else{
#     theta0.upper= C %*% mu.upper
#     theta0.lower= C %*% mu.lower
#     sigma0= C %*% diag(V) %*% t(C)
#     corr0=sigma0/sqrt(outer(diag(sigma0),diag(sigma0),"*"))
#   }
#
#   max.dev.vec=rep(NA, length(tau.vec))
#   dev.mat=matrix(NA, nrow=length(tau.vec), ncol=dim(C)[1])
#   for(j in 1:length(tau.vec)){
#     temp.tau=tau.vec[j]
#
#     ## compute the test statistic for each subgroup
#     temp.t.vec=rep(NA, num.of.subgroups)
#     null.values=matrix(NA, nrow=num.of.subgroups, ncol=2)
#     for(i in 1:num.of.subgroups){
#       subgroup=testData[subgroup.num==unique.subg[i],]
#       treated.y=subgroup[1:(length(subgroup[,1])/2),1]
#       control.y=subgroup[-(1:(length(subgroup[,1])/2)),1]
#       temp.t.vec[i]=wilcox.test(treated.y-temp.tau, control.y, paired=T, alternative="two.sided")$statistic
#     }
#
#     temp.test= C %*% temp.t.vec
#     if(dim(C)[1]==1){
#       temp.deviate.upper=(temp.test-theta0.upper)/sqrt(sigma0)
#       temp.deviate.lower=(temp.test-theta0.lower)/sqrt(sigma0)
#     }else{
#       temp.deviate.upper=(temp.test-theta0.upper)/sqrt(diag(sigma0))
#       temp.deviate.lower=(temp.test-theta0.lower)/sqrt(diag(sigma0))
#     }
#     # if two deviate bounds have the same sign, choose the minimum; otherwise, give 0.
#     same.sign=(temp.deviate.upper*temp.deviate.lower >= 0) # check whether two deviate bounds have the same sign.
#     temp.deviate=rep(0, length(temp.deviate.upper))
#     temp.deviate[same.sign==1]=pmin(abs(temp.deviate.upper), abs(temp.deviate.lower))[same.sign==1]
#     dev.mat[j,]=temp.deviate
#     max.deviate=max(abs(temp.deviate))
#     max.dev.vec[j]=max.deviate
#   }
#   critical.val=qmvnorm(1-tot.signif/2, mean=rep(0, length(corr0[,1])), corr=corr0)$quantile
#
#   sensi.mat[k,]=c(dev.mat[which.min(max.dev.vec),], min(max.dev.vec), critical.val)
#
# }
# sensi.mat=as.data.frame(sensi.mat)
# colnames(sensi.mat)[1:(dim(C)[1])] <- rownames(C)
# colnames(sensi.mat)[(dim(sensi.mat)[2]-1)]="Max"
# colnames(sensi.mat)[dim(sensi.mat)[2]]="kappa"
# sensi.mat$Gamma=sensi.param.vec
#
# sensi.mat # sensitivity table.
# opfit # the used tree
