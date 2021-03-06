# Gabriel Hoffman
# April 18, 2016

#' canCorPairs
#'
#' Assess correlation between all pairs of variables in a formula 
#'
#' @param formula standard linear model formula (doesn't support random effects currently, so just change the syntax)
#' @param data data.frame with the data for the variables in the formula
#' @param showWarnings default to true
#'
#' @details
#' Canonical Correlation Analysis (CCA) is similar to correlation between two vectors, except that CCA can accommodate matricies as well.  For a pair of variables, canCorPairs assesses the degree to which they co-vary and contain the same information.  Variables in the formula can be a continuous variable or a discrete variable expanded to a matrix (which is done in the backend of a regression model).  For a pair of variables, canCorPairs uses CCA to compute the correlation between these variables and returns the pairwise correlation matrix.
#' 
#' Statistically, let rho be the array of correlation values returned by the standard R function cancor to compute CCA.  canCorPairs returns rho / sum(rho) which is the fraction of the maximum possible correlation.   
#' 
#' Note that CCA returns correlations values between 0 and 1
#'
#' @return 
#' Matrix of correlation values between all pairs of variables.
#'
#' @examples
#'
#' # load library
#' # library(variancePartition)
#' 
#' # load simulated data:
#' data(varPartData)
#' 
#' # specify formula
#' form <- ~ Individual + Tissue + Batch + Age + Height
#'
#' # Compute Canonical Correlation Analysis (CCA)
#' # between all pairs of variables
#' # returns absolute correlation value  
#' C = canCorPairs( form, info)
#' 
#' # Plot correlation matrix
#' plotCorrMatrix( C )
#'
#' @importFrom stats model.matrix.lm cancor
#' @export
canCorPairs = function(formula, data, showWarnings=TRUE){

	formula = stats::as.formula( formula )

	if( .isMixedModelFormula(formula) ){
		stop("Invalid formula.\nSuggestion: this function does not handle random effects.\nUse ~ x instead of ~ (1|x) in formula\nBut may be due to other issue")
	}

	# keep rows even if they have NA's
	X = model.matrix.lm(formula, data, na.action="na.pass")

	varLabels = attr(terms(formula),"term.labels")

	if( length(varLabels) < 2 ){
		stop("Must include at least 2 variables in the formula")
	}

	# get grouping
	idx = attr(X, "assign")

	variableList = list()

	# extract data
	for( i in unique(idx)){
		if(i==0) next
		variableList[[varLabels[i]]] = X[,idx==i,drop=FALSE]
	}
	
	# Check that variables in formula are not constant
	checkNames = names(which(sapply(variableList, sd) == 0))
	if( length(checkNames) != 0 ){
		stop(paste("These variables have zero variance so cannot be analyzed:\n", paste(checkNames, collapse=', ' )))
	}

	C = matrix(NA, length(varLabels), length(varLabels))
	colnames(C) = varLabels
	rownames(C) = varLabels
	diag(C) = 1

	pairs = combn(varLabels, 2)

	colinear_set = c()

	for(i in 1:ncol(pairs)){
		key1 = pairs[1,i]
		key2 = pairs[2,i]

		value = tryCatch( {
			# keep only rows with no NA's
			keep1 = apply(variableList[[key1]], 1, function(x) !any(is.na(x)))
			keep2 = apply(variableList[[key2]], 1, function(x) !any(is.na(x)))
			keep = keep1 & keep2

			fit <- cancor( variableList[[key1]][keep,,drop=FALSE], variableList[[key2]][keep,,drop=FALSE] )
			sum(fit$cor) / length(fit$cor)
			},
			error = function(e){
			NA
			}
			)

		C[key1, key2] = value
		C[key2, key1] = value

		if( showWarnings & !is.na(value) & (value > .999) ){
			colinear_set = c(colinear_set, paste(key1, "and", key2))
		}
	}

	if( length(colinear_set) > 0){
		warning("Regression model may be problematic.\nHigh colinearity between variables:\n", paste(paste0('  ', colinear_set), collapse="\n"))
	}

	return( C )
}



