import { useState, useEffect } from "react";
import { useCollectionData, useCollection } from "react-firebase-hooks/firestore";
import { collection, query, orderBy, limit, doc, updateDoc, deleteDoc, Timestamp } from "firebase/firestore";
import { db } from "../firebase";
import { Star, MessageSquare, Calendar, User, Reply, Send, Trash2, RotateCcw, Search, Filter, TrendingUp, Award, AlertTriangle, Download } from "lucide-react";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import moment from "moment";

interface Review {
  id: string;
  userId: string;
  customerName?: string;
  orderId: string;
  rating: number;
  review: string;
  createdAt: any;
  adminReply?: string;
  adminReplyDate?: any;
}

export default function Reviews() {
  const [selectedRating, setSelectedRating] = useState<number | null>(null);
  const [userNames, setUserNames] = useState<{ [key: string]: string }>({});
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [replyText, setReplyText] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDeleting, setIsDeleting] = useState<string | null>(null);
  const [isClearing, setIsClearing] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [dateFilter, setDateFilter] = useState("all");
  const [sortBy, setSortBy] = useState("newest");
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [selectedReviews, setSelectedReviews] = useState<string[]>([]);
  
  const [reviewsSnapshot, loading, error] = useCollection(
    query(collection(db, "order_reviews"), orderBy("createdAt", "desc"), limit(100))
  );
  
  const reviews = reviewsSnapshot?.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  })) as Review[] || [];
  
  const [usersSnapshot] = useCollection(
    query(collection(db, "users"))
  );
  
  useEffect(() => {
    if (usersSnapshot?.docs) {
      const nameMap: { [key: string]: string } = {};
      usersSnapshot.docs.forEach((doc) => {
        const userData = doc.data();
        const userId = doc.id;
        nameMap[userId] = userData.name || userData.displayName || userData.email?.split('@')[0] || 'Anonymous Customer';
      });
      setUserNames(nameMap);

    }
  }, [usersSnapshot]);
  


  const filteredReviews = reviews?.filter((review: Review) => {
    // Rating filter
    if (selectedRating !== null && Math.round(review.rating || 0) !== selectedRating) {
      return false;
    }
    
    // Search filter
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      const customerName = (review.customerName || userNames[review.userId] || '').toLowerCase();
      const reviewText = (review.review || '').toLowerCase();
      const orderId = (review.orderId || '').toLowerCase();
      if (!customerName.includes(searchLower) && !reviewText.includes(searchLower) && !orderId.includes(searchLower)) {
        return false;
      }
    }
    
    // Date filter
    if (dateFilter !== "all" && review.createdAt?.seconds) {
      const reviewDate = moment(review.createdAt.seconds * 1000);
      switch (dateFilter) {
        case "today":
          if (!reviewDate.isSame(moment(), "day")) return false;
          break;
        case "week":
          if (!reviewDate.isSame(moment(), "week")) return false;
          break;
        case "month":
          if (!reviewDate.isSame(moment(), "month")) return false;
          break;
      }
    }
    
    return true;
  }).sort((a, b) => {
    switch (sortBy) {
      case "oldest":
        return (a.createdAt?.seconds || 0) - (b.createdAt?.seconds || 0);
      case "highest":
        return (b.rating || 0) - (a.rating || 0);
      case "lowest":
        return (a.rating || 0) - (b.rating || 0);
      default: // newest
        return (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0);
    }
  }) || [];

  const averageRating = reviews?.length 
    ? (reviews.reduce((sum: number, review: Review) => sum + (review.rating || 0), 0) / reviews.length).toFixed(1)
    : "0.0";

  const ratingCounts = [5, 4, 3, 2, 1].map(rating => ({
    rating,
    count: reviews?.filter((r: Review) => Math.round(r.rating || 0) === rating).length || 0
  }));

  // Analytics calculations
  const analytics = {
    totalReviews: reviews?.length || 0,
    averageRating: parseFloat(averageRating),
    positiveReviews: reviews?.filter(r => (r.rating || 0) >= 4).length || 0,
    negativeReviews: reviews?.filter(r => (r.rating || 0) <= 2).length || 0,
    repliedReviews: reviews?.filter(r => r.adminReply).length || 0,
    recentReviews: reviews?.filter(r => 
      r.createdAt?.seconds && moment(r.createdAt.seconds * 1000).isAfter(moment().subtract(7, 'days'))
    ).length || 0
  };

  const exportReviewsToPDF = () => {
    const pdfDoc = new jsPDF();
    pdfDoc.setFontSize(24);
    pdfDoc.text("Taste of African Cuisine", 14, 20);
    pdfDoc.setFontSize(16);
    pdfDoc.text("Customer Reviews Report", 14, 35);
    pdfDoc.setFontSize(12);
    pdfDoc.text(`Generated: ${moment().format("MMMM D, YYYY")}`, 14, 45);
    pdfDoc.text(`Average Rating: ${averageRating}/5.0 (${reviews?.length || 0} reviews)`, 14, 55);

    autoTable(pdfDoc, {
      startY: 65,
      head: [["Customer", "Rating", "Review", "Date", "Admin Reply"]],
      body: filteredReviews.map(review => [
        review.customerName || userNames[review.userId] || 'Anonymous',
        `${review.rating}/5`,
        (review.review || 'No comment').substring(0, 100) + (review.review?.length > 100 ? '...' : ''),
        formatDate(review.createdAt),
        review.adminReply ? 'Yes' : 'No'
      ]),
    });

    pdfDoc.save(`Reviews_Report_${moment().format("YYYY_MM_DD")}.pdf`);
  };

  const handleBulkDelete = async () => {
    if (selectedReviews.length === 0) {
      toast.error("Please select reviews first");
      return;
    }

    if (!confirm(`Delete ${selectedReviews.length} selected reviews?`)) return;

    try {
      const promises = selectedReviews.map(reviewId => deleteDoc(doc(db, "order_reviews", reviewId)));
      await Promise.all(promises);
      toast.success(`Deleted ${selectedReviews.length} reviews`);
      setSelectedReviews([]);
    } catch {
      toast.error("Failed to delete reviews");
    }
  };

  const handleSelectAll = () => {
    if (selectedReviews.length === filteredReviews.length) {
      setSelectedReviews([]);
    } else {
      setSelectedReviews(filteredReviews.map(r => r.id));
    }
  };

  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star
        key={i}
        className={`w-4 h-4 ${
          i < rating ? "text-yellow-400 fill-current" : "text-gray-300"
        }`}
      />
    ));
  };

  const formatDate = (timestamp: any) => {
    if (!timestamp) return "Unknown date";
    const date = timestamp.seconds ? new Date(timestamp.seconds * 1000) : new Date(timestamp);
    return date.toLocaleDateString() + " " + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const handleReplySubmit = async (reviewId: string) => {
    if (!replyText.trim()) {
      alert('Please enter a reply message');
      return;
    }
    
    if (!reviewId) {
      alert('Invalid review ID');
      return;
    }
    
    setIsSubmitting(true);
    try {
      const reviewRef = doc(db, "order_reviews", reviewId);
      await updateDoc(reviewRef, {
        adminReply: replyText.trim(),
        adminReplyDate: Timestamp.now()
      });
      
      setReplyingTo(null);
      setReplyText('');
      
      alert('Reply sent successfully!');
      
    } catch (error) {
      console.error('Error sending reply:', error);
      alert('Failed to send reply: ' + error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteReview = async (reviewId: string) => {
    if (!confirm('Are you sure you want to delete this review? This action cannot be undone.')) {
      return;
    }

    setIsDeleting(reviewId);
    try {
      await deleteDoc(doc(db, "order_reviews", reviewId));
      alert('Review deleted successfully!');
    } catch (error) {
      console.error('Error deleting review:', error);
      alert('Failed to delete review: ' + error.message);
    } finally {
      setIsDeleting(null);
    }
  };

  const handleClearReply = async (reviewId: string) => {
    if (!confirm('Are you sure you want to clear your reply to this review?')) {
      return;
    }

    setIsClearing(reviewId);
    try {
      await updateDoc(doc(db, "order_reviews", reviewId), {
        adminReply: null,
        adminReplyDate: null
      });
      alert('Reply cleared successfully!');
    } catch (error) {
      console.error('Error clearing reply:', error);
      alert('Failed to clear reply: ' + error.message);
    } finally {
      setIsClearing(null);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-4">
        <p className="text-red-600">Error loading reviews: {error.message}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Reviews</h1>
          <p className="text-gray-600">Monitor and respond to customer feedback.</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowAnalytics(!showAnalytics)}
            className="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition-colors flex items-center gap-2"
          >
            <TrendingUp className="w-4 h-4" />
            Analytics
          </button>
          <button
            onClick={exportReviewsToPDF}
            className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition-colors flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export PDF
          </button>
        </div>
      </div>

      {/* Analytics Dashboard */}
      {showAnalytics && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Review Analytics</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
            <div className="bg-blue-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <MessageSquare className="w-5 h-5 text-blue-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Total</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.totalReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-yellow-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Star className="w-5 h-5 text-yellow-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Avg Rating</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.averageRating.toFixed(1)}</p>
                </div>
              </div>
            </div>
            <div className="bg-green-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Award className="w-5 h-5 text-green-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Positive</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.positiveReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-red-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-5 h-5 text-red-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Negative</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.negativeReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-purple-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Reply className="w-5 h-5 text-purple-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Replied</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.repliedReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-orange-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Calendar className="w-5 h-5 text-orange-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">This Week</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.recentReviews}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Search and Filters */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex flex-col lg:flex-row gap-4 items-start lg:items-center justify-between">
          <div className="flex flex-col sm:flex-row gap-4 flex-1">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search reviews by customer, order ID, or content..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              />
            </div>
            
            <div className="flex items-center gap-2">
              <Calendar className="text-gray-400 w-5 h-5" />
              <select
                value={dateFilter}
                onChange={(e) => setDateFilter(e.target.value)}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">This Week</option>
                <option value="month">This Month</option>
              </select>
            </div>
            
            <div className="flex items-center gap-2">
              <Filter className="text-gray-400 w-5 h-5" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="newest">Newest First</option>
                <option value="oldest">Oldest First</option>
                <option value="highest">Highest Rating</option>
                <option value="lowest">Lowest Rating</option>
              </select>
            </div>
          </div>
          
          {(searchTerm || dateFilter !== "all") && (
            <button
              onClick={() => {
                setSearchTerm("");
                setDateFilter("all");
              }}
              className="text-sm text-gray-600 hover:text-gray-800 underline"
            >
              Clear filters
            </button>
          )}
        </div>
      </div>

      {/* Bulk Actions */}
      {selectedReviews.length > 0 && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <span className="text-sm font-medium text-red-900">
                {selectedReviews.length} review(s) selected
              </span>
              <button
                onClick={() => setSelectedReviews([])}
                className="text-sm text-red-600 hover:text-red-800"
              >
                Clear selection
              </button>
            </div>
            <button
              onClick={handleBulkDelete}
              className="px-4 py-2 bg-red-600 text-white text-sm rounded-lg hover:bg-red-700 flex items-center gap-2"
            >
              <Trash2 className="w-4 h-4" />
              Delete Selected
            </button>
          </div>
        </div>
      )}

      {/* Rating Overview */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="text-center">
            <div className="text-4xl font-bold text-gray-900 mb-2">{averageRating}</div>
            <div className="flex justify-center mb-2">
              {renderStars(Math.round(parseFloat(averageRating)))}
            </div>
            <p className="text-gray-600">Average Rating</p>
          </div>
          
          <div className="space-y-2">
            {ratingCounts.map(({ rating, count }) => (
              <div key={`rating-${rating}`} className="flex items-center space-x-2">
                <span className="text-sm font-medium w-8">{rating}★</span>
                <div className="flex-1 bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-yellow-400 h-2 rounded-full"
                    style={{
                      width: `${reviews?.length ? (count / reviews.length) * 100 : 0}%`
                    }}
                  ></div>
                </div>
                <span className="text-sm text-gray-600 w-8">{count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Results Summary */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-600">
          Showing {filteredReviews.length} of {reviews?.length || 0} reviews
        </p>
        {filteredReviews.length > 0 && (
          <button
            onClick={handleSelectAll}
            className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1"
          >
            {selectedReviews.length === filteredReviews.length ? 'Deselect All' : 'Select All'}
          </button>
        )}
      </div>

      {/* Filter Buttons */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setSelectedRating(null)}
          className={`px-4 py-2 rounded-lg text-sm font-medium ${
            selectedRating === null
              ? "bg-orange-500 text-white"
              : "bg-gray-100 text-gray-700 hover:bg-gray-200"
          }`}
        >
          All Reviews
        </button>
        {[5, 4, 3, 2, 1].map(rating => (
          <button
            key={`filter-${rating}`}
            onClick={() => setSelectedRating(rating)}
            className={`px-4 py-2 rounded-lg text-sm font-medium flex items-center space-x-1 ${
              selectedRating === rating
                ? "bg-orange-500 text-white"
                : "bg-gray-100 text-gray-700 hover:bg-gray-200"
            }`}
          >
            <span>{rating}</span>
            <Star className="w-3 h-3" />
          </button>
        ))}
      </div>

      {/* Reviews List */}
      <div className="space-y-4">
        {filteredReviews.length === 0 ? (
          <div className="text-center py-12">
            <MessageSquare className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-500">
              {selectedRating ? `No ${selectedRating}-star reviews found` : "No reviews yet"}
            </p>
          </div>
        ) : (
          filteredReviews.map((review: Review, index: number) => (
            <div key={review.id || `review-${index}`} className="bg-white rounded-lg shadow p-6">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <input
                    type="checkbox"
                    checked={selectedReviews.includes(review.id)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setSelectedReviews([...selectedReviews, review.id]);
                      } else {
                        setSelectedReviews(selectedReviews.filter(id => id !== review.id));
                      }
                    }}
                    className="rounded border-gray-300"
                  />
                  <div className="w-10 h-10 bg-orange-100 rounded-full flex items-center justify-center">
                    <User className="w-5 h-5 text-orange-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900">
                      {review.customerName || userNames[review.userId] || `Customer ${review.userId?.slice(-4) || 'Unknown'}`}
                    </h3>
                    <p className="text-sm text-gray-500">Order: {review.orderId}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <div className="flex">{renderStars(review.rating)}</div>
                  <span className="text-sm text-gray-600 flex items-center">
                    <Calendar className="w-3 h-3 mr-1" />
                    {formatDate(review.createdAt)}
                  </span>
                  <div className="flex items-center space-x-1 ml-2">
                    {review.adminReply && (
                      <button
                        onClick={() => handleClearReply(review.id)}
                        disabled={isClearing === review.id}
                        className="p-1 text-yellow-600 hover:text-yellow-700 hover:bg-yellow-50 rounded transition-colors"
                        title="Clear Reply"
                      >
                        <RotateCcw className="w-4 h-4" />
                      </button>
                    )}
                    <button
                      onClick={() => handleDeleteReview(review.id)}
                      disabled={isDeleting === review.id}
                      className="p-1 text-red-600 hover:text-red-700 hover:bg-red-50 rounded transition-colors"
                      title="Delete Review"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
              
              <div className="bg-gray-50 rounded-lg p-4 space-y-4">
                <div>
                  <p className="text-gray-700 font-medium mb-1">Customer Review:</p>
                  <p className="text-gray-700">
                    {review.review || "No written review provided."}
                  </p>
                </div>
                
                {/* Admin Reply Section */}
                {review.adminReply ? (
                  <div className="border-l-4 border-orange-500 pl-4 bg-orange-50 rounded-r-lg p-3">
                    <div className="flex items-center gap-2 mb-2">
                      <Reply className="w-4 h-4 text-orange-600" />
                      <span className="text-sm font-medium text-orange-800">Admin Response</span>
                      <span className="text-xs text-orange-600">
                        {review.adminReplyDate ? formatDate(review.adminReplyDate) : ''}
                      </span>
                    </div>
                    <p className="text-orange-900">{review.adminReply}</p>
                  </div>
                ) : (
                  <div className="pt-2 border-t border-gray-200">
                    {replyingTo === review.id ? (
                      <div className="space-y-3">
                        <textarea
                          value={replyText}
                          onChange={(e) => setReplyText(e.target.value)}
                          placeholder="Write your response to this review..."
                          className="w-full p-3 border border-gray-300 rounded-lg resize-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                          rows={3}
                          disabled={isSubmitting}
                        />
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleReplySubmit(review.id)}
                            disabled={!replyText.trim() || isSubmitting}
                            className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                          >
                            <Send className="w-4 h-4" />
                            {isSubmitting ? 'Sending...' : 'Send Reply'}
                          </button>
                          <button
                            onClick={() => {
                              setReplyingTo(null);
                              setReplyText('');
                            }}
                            disabled={isSubmitting}
                            className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button
                        onClick={() => setReplyingTo(review.id)}
                        className="flex items-center gap-2 px-3 py-2 text-orange-600 hover:text-orange-700 hover:bg-orange-50 rounded-lg transition-colors text-sm font-medium"
                      >
                        <Reply className="w-4 h-4" />
                        Reply to Review
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}