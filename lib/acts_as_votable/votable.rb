module ActsAsVotable
  module Votable

    def self.included(base)
      base.send :include, ActsAsVotable::Votable::InstanceMethods
      # base.extend ActsAsVotable::Votable::ClassMethods
    end


    module ClassMethods
    end

    module InstanceMethods

      attr_accessor :vote_registered

      def vote_registered?
        return self.vote_registered
      end

      def default_conditions
        {
          :votable_id => self.id,
          :votable_type => self.class.base_class.name.to_s
        }
      end

      # voting
      def vote args = {}

        options = ActsAsVotable::Vote.default_voting_args.merge(args)
        self.vote_registered = false

        if options[:voter].nil?
          return false
        end

        # find the vote
        votes = find_votes({
            :voter_id => options[:voter].id,
            :voter_type => options[:voter].class.name
          })

        if votes.count == 0
          # this voter has never voted
          vote = ActsAsVotable::Vote.new(
            :votable => self,
            :voter => options[:voter]
          )
        else
          # this voter is potentially changing his vote
          vote = votes.first
        end


        vote_flag = ActsAsVotable::Vote.word_is_a_vote_for(options[:vote])
        toggle_vote = options[:toggle_vote]

        last_update = vote.updated_at
        previous_vote_flag = vote.vote_flag

        updated = case
        when vote.new_record? || toggle_vote
          vote.vote_flag = vote_flag
          self.vote_registered = vote.save && last_update != vote.updated_at
        when vote_flag != previous_vote_flag
          vote.delete
          true
        when vote_flag == previous_vote_flag
          self.vote_registered = false
        end
        update_cached_votes if updated

      end

      def vote_up(voter, toggle_vote = true)
        self.vote :voter => voter, :vote => true, :toggle_vote => toggle_vote
      end

      def vote_down(voter, toggle_vote = true)
        self.vote :voter => voter, :vote => false, :toggle_vote => toggle_vote
      end

      # caching
      def update_cached_votes

        updates = {}

        if self.respond_to?(:cached_votes_total=)
          updates[:cached_votes_total] = count_votes_total(true)
        end

        if self.respond_to?(:cached_votes_up=)
          updates[:cached_votes_up] = count_votes_up(true)
        end

        if self.respond_to?(:cached_votes_down=)
          updates[:cached_votes_down] = count_votes_down(true)
        end

        self.update_attributes(updates) if updates.size > 0

      end


      # results
      def find_votes extra_conditions = {}
        ActsAsVotable::Vote.where(default_conditions.merge(extra_conditions))
      end
      alias :votes :find_votes

      def up_votes
        find_votes(:vote_flag => true)
      end

      def down_votes
        find_votes(:vote_flag => false)
      end


      # counting
      def count_votes_total skip_cache = false
        if !skip_cache && self.respond_to?(:cached_votes_total)
          return self.send(:cached_votes_total)
        end
        find_votes.size
      end

      def count_votes_up skip_cache = false
        if !skip_cache && self.respond_to?(:cached_votes_up)
          return self.send(:cached_votes_up)
        end
        up_votes.size
      end

      def count_votes_down skip_cache = false
        if !skip_cache && self.respond_to?(:cached_votes_down)
          return self.send(:cached_votes_down)
        end
        down_votes.size
      end

      # voters
      def voted_on_by? voter
        votes = find_votes :voter_id => voter.id, :voter_type => voter.class.name
        votes.size > 0
      end

    end

  end
end
