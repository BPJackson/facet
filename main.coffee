@Tags = new Meteor.Collection 'tags'
@Items = new Meteor.Collection 'items'

Items.helpers
    author: -> Meteor.users.findOne @authorId
    bidder: -> if @bidderId then Meteor.users.findOne @bidderId


Meteor.methods
    clickVoteButton: (itemId, direction)->

        item = Items.findOne itemId
        me = Meteor.userId()

        if direction is 'up'
            # if I've upvoted, undo upvote
            if item.upvoters.indexOf(me) > -1
                Meteor.call 'undovote', itemId, 'up', (err)-> if err then console.err err

            # if I've downvoted, undo downvote
            if item.downvoters.indexOf(me) > -1
                Meteor.call 'undovote', itemId, 'down', (err)-> if err then console.err err
                Meteor.call 'vote', itemId, 'up', (err)-> if err then console.err err

            else Meteor.call 'vote', itemId, 'up', (err)-> if err then console.err err

        if direction is 'down'
            # if I've downvoted, undo downvote
            if item.downvoters.indexOf(me) > -1
                Meteor.call 'undovote', itemId, 'down', (err)-> if err then console.err err

            # if I've upvoted, undo upvote
            if item.upvoters.indexOf(me) > -1
                Meteor.call 'undovote', itemId, 'up', (err)-> if err then console.err err
                Meteor.call 'vote', itemId, 'down', (err)-> if err then console.err err

            else Meteor.call 'vote', itemId, 'down', (err)-> if err then console.err err

    vote: (itemId, direction)->
        item = Items.findOne itemId

        if direction is 'up'
            Items.update itemId, {
                $inc:
                    points: 1
                    upvotes: 1
                $addToSet: upvoters: Meteor.userId()
            },(err)-> if err then console.err err

            Meteor.call 'changeUserPoints', item.authorId, 1, (err)-> if err then console.err err

        if direction is 'down'
            Items.update itemId,{
                $inc:
                    points: -1
                    downvotes: 1
                $addToSet: downvoters: Meteor.userId()
            },(err)-> if err then console.err err

            Meteor.call 'changeUserPoints', item.authorId, -1, (err)-> if err then console.err err


    undovote:  (itemId, direction)->
        item = Items.findOne itemId
        me = Meteor.userId()
        if direction is 'up'

            Meteor.call 'changeUserPoints', item.authorId, -1, (err)-> if err then console.log err
            Items.update itemId, {
                $pull:
                    upvoters: me
                $inc:
                    upvotes: -1
                    points: -1
            },(err)-> if err then console.error err

        if direction is 'down'
            Items.update itemId, {
                $pull:
                    downvoters: Meteor.userId()
                $inc:
                    downvotes: -1
                    points: 1
            },(err)-> if err then console.err err

            Meteor.call 'changeUserPoints', item.authorId, 1, (err)-> if err then console.err err

    isIn: (string, array)-> if array.indexOf(string) > -1 then true else false

    makeDayAuction: (itemId)->
        auction = Items.findOne itemId
        dayFromNow = Date.now() + 86400000 # 1000ms * 60s * 60min * 24hr
        Items.update itemId,
            $addToSet: tags: 'day auction'
            $unset: upvotes:'', upvoters:'', downvotes:'', downvoters:'', points:''
            $set: isAuction: true, auctionEnd: dayFromNow, bid: 0,

    changeUserPoints: (uid, amount)-> Meteor.users.update uid, $inc: points: amount

    givePoints: (giverId, points, receiverId)->
        Meteor.call 'changeUserPoints', receiverId, points
        Meteor.call 'changeUserPoints', giverId, points

    bid: (itemId)->
        me = Meteor.userId()
        item = Items.findOne itemId

        Meteor.call 'givePoints', me, 1, item.author, (err)-> if err then console.err err


        Items.update itemId,
            $inc: bid: 1
            $set: bidderId: me

    placeBid: (itemId)->
        me = Meteor.userId()
        item = Items.findOne itemId

        bid = item.bid
        bidder = item.bidderId

        if bidder? and bidder is not me then Meteor.call 'givePoints', me, bid, bidder, (err)-> if err then console.err err
        Meteor.call 'bid', itemId


Items.before.insert (userId, doc) ->
    doc.timestamp = Date.now()
    doc.authorId = Meteor.userId()
    doc.upvotes = 0
    doc.upvoters = []
    doc.downvotes = 0
    doc.downvoters = []
    doc.points = 0

if Meteor.isClient
    Session.setDefault 'editing', null
    tagFilter = new ReactiveArray []
    authorFilter = new ReactiveArray []

    Accounts.ui.config passwordSignupFields: 'USERNAME_ONLY'
    Tracker.autorun -> Meteor.subscribe 'tags', tagFilter.array(), authorFilter.array()
    Tracker.autorun -> Meteor.subscribe 'items', tagFilter.array(), authorFilter.array()

    Meteor.subscribe 'users'

    Template.home.onCreated ->
        $(window).on 'keyup', (e) ->
            if e.keyCode is 78 and e.shiftKey and e.altKey
                newId = Items.insert {}
                Session.set 'editing', newId

    Template.home.events
        'click .add': ->
            newId = Items.insert {}
            Session.set 'editing', newId
        'click .filterTag': -> tagFilter.push @name.toString()
        'click .unfilterTag': -> tagFilter.remove @toString()

        'click .unfilterAuthor': -> authorFilter.remove @toString()
        'click .userCloudTag': (e)-> if tagFilter.array().indexOf(@name) is -1 then tagFilter.push @name

    Template.home.helpers
        globalTags: ->
            itemCount = Items.find().count()
            Tags.find {count: $lt: itemCount}, limit: 10
        tagFilterList: -> tagFilter.list()
        authorFilterList: -> authorFilter.list()
        items: -> Items.find {}, sort: timestamp: -1
        user: -> Meteor.user()

    Template.item.helpers
        isAuction: -> @isAuction
        isEditing: -> Session.equals 'editing', @_id
        isAuthor: -> @authorId is Meteor.userId()

        canEdit: -> Meteor.userId()  is @authorId
        canClone: -> Meteor.userId()

        whenCreated: -> moment.utc(@timestamp).fromNow()
        whenEnd: -> moment.utc(@auctionEnd).fromNow()

        authorPoints: ->
            author = Meteor.users.findOne @authorId
            if author then author.points
        upButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''
        downButtonClass: -> if not Meteor.userId() or @authorId is Meteor.userId() then 'disabled' else ''

        upIconClass: ->
            if @upvoters.indexOf(Meteor.userId()) > -1 then 'thumbs up' else 'thumbs up outline'
        downIconClass: ->
            if @downvoters.indexOf(Meteor.userId()) > -1 then 'thumbs down' else 'thumbs down outline'

        authorButtonClass: ->
            if @author()
                name = @author().username
                if Meteor.call 'isIn', name, authorFilter.array() then 'disabled' else ''

        newBid: -> @bid + 1
        canBid: ->
            userId = Meteor.userId()
            if not userId then'disabled'
            else if @authorId is Meteor.userId() then 'disabled'
            else if Meteor.user().points < @bid then 'disabled'
            else ''


    Template.item.events
        'click .itemtag': (e)->
            tagName = e.target.textContent
            if tagFilter.array().indexOf(tagName) is -1 then tagFilter.push tagName

        'click .edit': (e,t)->
            $('.viewarea').dimmer('show')
            Session.set 'editing', @_id

        'click .save': (e,t)->
            val = t.find('textarea').value
            Items.update @_id, $set: body: val

            $('.viewarea').dimmer('hide')
            Session.set 'editing', null

        'click .clone': (e)->
            $('.viewarea').dimmer('show')
            cloneId = Items.insert {
                tags: @tags
                body: @body
                }
            Session.set 'editing', cloneId

        'click .username': (e)-> authorFilter.push @author().username

        'click .upvote': -> Meteor.call 'clickVoteButton', @_id, 'up'
        'click .downvote': -> Meteor.call 'clickVoteButton', @_id, 'down'

        'click .delete': ->
            $('.viewarea').dimmer('hide')
            Items.remove @_id

        'click .bid': -> Meteor.call 'placeBid', @_id

    Template.editing.events
        'keyup input, keyup textarea':(e,t)->

            #control-c to save body input
            if (event.keyCode is 10 or event.keyCode is 13) and event.ctrlKey

                val = t.find('textarea').value
                Items.update @_id, $set: body: val

                $('.viewarea').dimmer('hide')
                Session.set 'editing', null

    Template.editing.onRendered ->
        self = @
        @$('#tagselector').dropdown
            allowAdditions: true
            placeholder: 'add tags'
            onAdd: (addedValue) ->

                switch addedValue
                    when 'delete this'
                        Items.remove self.data._id
                        $('.viewarea').dimmer('hide')
                        Meteor.call 'calcUserCloud', Meteor.userId()
                    when 'day auction'
                        Meteor.call 'makeDayAuction', self.data._id
                        $('.viewarea').dimmer('hide')
                        Meteor.call 'calcUserCloud', Meteor.userId()
                    else
                        Items.update self.data._id, $addToSet: tags: addedValue
                        Meteor.call 'calcUserCloud', Meteor.userId()


            onRemove: (removedValue) -> Items.update self.data._id, $pull: tags: removedValue

if Meteor.isServer
    Accounts.onCreateUser (options, user) ->
        user.points = 0
        user.cloud = []
        user

    Items.allow
        insert: (userId, doc)-> doc.authorId is userId
        update: (userId, doc)-> true
        remove: (userId, doc)-> doc.authorId is userId

    Meteor.methods

        calcUserCloud: (userId) ->

            userCloud = Items.aggregate [
                { $match: authorId: userId }
                { $project: tags: 1 }
                { $unwind: '$tags' }
                { $group: _id: '$tags', count: $sum: 1 }
                { $sort: count: -1 }
                { $limit: 5 }
                { $project: _id: 0, name: '$_id', count: 1 }
                ]

            Meteor.users.update { _id: userId }, $set: cloud: userCloud


    Meteor.publish 'users', ->
        Meteor.users.find()

    Meteor.publish 'items', (tagFilter, authorFilter)->

        match = {}

        if tagFilter.length > 0 then match.tags= $all: tagFilter

        if authorFilter.length > 0
            author = Meteor.users.findOne username: authorFilter[0]
            match.authorId= author._id

        Items.find match, limit: 10

    Meteor.publish 'tags', (tagFilter, authorFilter)->
        self = @
        match = {}

        if tagFilter.length > 0 then match.tags= $all: tagFilter

        if authorFilter.length > 0
            author = Meteor.users.findOne username: authorFilter[0]
            match.authorId= author._id


        cloud = Items.aggregate [
            { $match: match }
            { $project: tags: 1 }
            { $unwind: '$tags' }
            { $group: _id: '$tags', count: $sum: 1 }
            { $match: _id: $nin: tagFilter }
            { $sort: count: -1 }
            { $project: _id: 0, name: '$_id', count: 1 }
            ]


        cloud.forEach (tag) ->
            self.added 'tags', Random.id(),
                name: tag.name
                count: tag.count

        self.ready()
